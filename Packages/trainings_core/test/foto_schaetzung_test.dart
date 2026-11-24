import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für die **Foto-Schätzung im Kern** (#335) — die Antwort der KI
/// prüfen, Posten auf Plausibilität sehen, eine Menge umrechnen und
/// festlegen, was vorab übernommen ist.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf **ausgeführt, nie verändert** werden.
///
/// ## Woher die Regeln kommen
///
/// Spec `docs/superpowers/specs/2026-11-04-ki-zugang-design.md`, Abschnitte
/// „Antwortschema", „Plausibilität (Kern)" und „Foto-Schätzung als erste
/// Aktion"; Plan `docs/superpowers/plans/2026-11-04-ki-zugang.md`, Task 4
/// samt „Review Focus" 4.
///
/// - **Die App prüft die Antwort selbst gegen das Schema**, egal was Gemini
///   garantiert. Der Kern nimmt die **dekodierte** Map, nie JSON-Text.
///   Schemaverletzung → `FormatException`.
/// - Je Posten Gramm und Nährwerte **für diese Menge**, nicht je 100 g.
///   `grams` und alle Nährwerte dürfen `null` sein — **`null` bleibt
///   `null`, nie `0`.**
/// - **Plausibel** ist ein Posten, wenn `kcal`, Eiweiß, Kohlenhydrate und
///   Fett da sind und `|kcal − (4E + 4K + 9F)| ≤ 0,2 · kcal + 10`.
/// - **Sicher** = `confident && gramm != null && kcal != null &&
///   plausibel`. Ein unplausibler Posten ist unsicher, auch wenn die KI
///   `confident: true` sagt.
/// - **Menge ändern** skaliert linear aus dem geschätzten Posten, die Zeile
///   heißt danach „von dir".
/// - **Unsichere Posten ohne Menge sind nicht vorab übernommen**; was Tim
///   berührt hat, schon. **Ein unsicherer Posten mit Menge ist übernommen**
///   und bleibt dabei unsicher (#407, Tims Meldung vom 07.11.2026: Er
///   konnte einen unsicheren Posten nicht direkt buchen, sondern musste
///   erst die Menge anfassen). Bis #407 galt: unsicher und unberührt heißt
///   nicht übernommen — die Fälle dazu sind umgestellt.
///
/// Alle Lebensmittel und Zahlen sind **erfunden** — keine echten
/// Mahlzeiten, keine Nährwertauskunft. Die Zahlen sind so gewählt, dass die
/// Rechnung von Hand aufgeht.
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// Neu in `Packages/trainings_core/lib/src/foto_schaetzung.dart`,
/// exportiert über `lib/trainings_core.dart`:
///
/// ```dart
/// enum PostenHerkunft { erkannt, vonDir, ergaenzt }
///
/// class SchaetzPosten {
///   const SchaetzPosten({
///     required this.name,
///     required this.gramm,
///     required this.werte,
///     required this.sicher,
///     required this.herkunft,
///   });
///   final String name;
///   final double? gramm;
///   final Naehrwerte werte;       // für diese Menge
///   final bool sicher;
///   final PostenHerkunft herkunft;
///   // == und hashCode über alle Felder
/// }
///
/// sealed class SchaetzAntwort {}
/// final class Erkannt extends SchaetzAntwort {
///   final String titel;
///   final List<SchaetzPosten> posten;
///   final String? notiz;
/// }
/// final class KeinEssen extends SchaetzAntwort {}
///
/// SchaetzAntwort leseAntwort(Map<String, Object?> json);
/// bool plausibel(Naehrwerte w);
/// SchaetzPosten mitMenge(SchaetzPosten p, double gramm);
/// List<SchaetzPosten> uebernommen(List<SchaetzPosten> posten);
/// ```
///
/// Abbildung der Antwortfelder: `name` → `name`, `grams` → `gramm`,
/// `kcal` → `werte.kcal`, `proteinG` → `werte.eiweissG`, `carbsG` →
/// `werte.kohlenhydrateG`, `fatG` → `werte.fettG`; `title` → `titel`,
/// `note` → `notiz`. Jeder Posten aus der Antwort hat die Herkunft
/// `erkannt`. Die übrigen Felder von [Naehrwerte] bleiben `null`.
///
/// ## Entscheidungen des Test-Agenten, wo der Auftrag offen ist
///
/// **Nicht von Tim freigegeben** — jede mit Begründung.
///
/// - **Der Konstruktor von [SchaetzPosten] ist benannt und `required`**,
///   auch für das nullbare `gramm`: Ein vergessenes Gramm soll ein
///   Kompilierfehler sein, kein stilles `null`.
/// - **Ein fehlender Nährwert-Schlüssel ist `null`, kein Fehler** — wie ein
///   ausdrückliches `null`. Beide heißen „keine Angabe"; wichtig ist allein,
///   dass daraus nie `0` wird.
/// - **Ganze Zahlen aus dem JSON sind Zahlen.** `jsonDecode` liefert `140`
///   als `int` und `43.4` als `double`; beides ist gültig.
/// - **`isFood: false` ist `KeinEssen`, auch wenn `items` fehlt oder Posten
///   enthält.** Die KI widerspricht sich dann selbst; nichts zu buchen ist
///   die vorsichtige Lesart.
/// - **`note` fehlt oder ist `null` → `notiz == null`.**
/// - **Ein Posten ohne `name`, ein Posten, der keine Map ist, und ein
///   `confident`, das kein `bool` ist, werfen** — dieselbe Klasse von
///   Schemaverletzung wie „Zahl als Text".
/// - **Die Toleranzgrenze gehört zu „plausibel".** Der Plan schreibt
///   `> 0,2·kcal + 10` für unplausibel; genau auf der Grenze ist also
///   plausibel.
/// - **Null ist eine Angabe.** Ein Posten mit 0 kcal und 0 g Makros (etwa
///   Wasser) ist plausibel.
/// - **[mitMenge] ohne geschätzte Menge macht alle Nährwerte `null`**, auch
///   wenn die KI für den Posten `kcal` geliefert hat. Der Plan sagt „bei
///   `p.gramm == null` → Nährwerte bleiben `null`"; ein Wert für eine
///   unbekannte Menge ist kein Wert für die neue — ihn stehen zu lassen,
///   zeigte unter Tims Menge eine Zahl, die zu einer anderen gehört.
/// - **[mitMenge] mit 0 g ergibt 0, nicht `null`** — eine gewogene Null
///   (wie `Naehrwerte.fuerMenge`).
/// - **„Von Tim berührt" heißt Herkunft `vonDir` oder `ergaenzt`.** Eine
///   ergänzte Zeile hat Tim über die Suche selbst hinzugefügt.
/// - **[uebernommen] behält die Reihenfolge.**
/// - **„Mit Menge" heißt `gramm != null`, sonst nichts** (#407). Tims
///   Wortlaut nennt nur die Menge; ein unsicherer Posten mit Menge, aber
///   ohne kcal, ist deshalb übernommen — seine fehlenden Werte bleiben
///   `null` und die Summe sagt „mind.". Festlegung des Test-Agenten,
///   **nicht von Tim**.
/// - **[uebernommen] ändert keinen Posten** — auch `sicher` nicht. Der
///   übernommene unsichere Posten trägt weiter `sicher: false`, damit die
///   Zeile „unsicher" sagt (#407). Und `uebernommen` ist idempotent;
///   `KiAktionen.fuehreAus` filtert ein zweites Mal.
/// - Was hier **nicht** festgelegt ist: `isFood: true` mit leerem `items`,
///   ein fehlendes `title`, `sicher` nach [mitMenge], `grams: 0` (auch
///   nicht, ob `0 g` eine Menge im Sinne von #407 ist) und negative
///   Nährwerte.
void main() {
  Map<String, Object?> posten({
    String name = 'Prüfhuhn, gegrillt',
    Object? grams = 140,
    Object? kcal = 231,
    Object? proteinG = 43.4,
    Object? carbsG = 0,
    Object? fatG = 5.0,
    Object? confident = true,
  }) => {
    'name': name,
    'grams': grams,
    'kcal': kcal,
    'proteinG': proteinG,
    'carbsG': carbsG,
    'fatG': fatG,
    'confident': confident,
  };

  Map<String, Object?> antwort(
    List<Object?> items, {
    String title = 'Prüfteller mit Reis',
    Object? note,
  }) => {'isFood': true, 'title': title, 'items': items, 'note': ?note};

  SchaetzPosten einzig(Map<String, Object?> json) {
    final a = leseAntwort(json);
    expect(a, isA<Erkannt>());
    return (a as Erkannt).posten.single;
  }

  SchaetzPosten sp(
    String name, {
    double? gramm = 100,
    Naehrwerte werte = const Naehrwerte(kcal: 100),
    bool sicher = true,
    PostenHerkunft herkunft = PostenHerkunft.erkannt,
  }) => SchaetzPosten(
    name: name,
    gramm: gramm,
    werte: werte,
    sicher: sicher,
    herkunft: herkunft,
  );

  // ═════════════════════════════════════════════════════════════════════
  group('leseAntwort — Erkannt', () {
    test('liest Titel, Notiz und den Posten aus dem Beispiel der Spec', () {
      final a = leseAntwort(antwort([posten()], note: 'Soße kaum erkennbar'));
      expect(a, isA<Erkannt>());
      final e = a as Erkannt;
      expect(e.titel, 'Prüfteller mit Reis');
      expect(e.notiz, 'Soße kaum erkennbar');
      expect(e.posten, hasLength(1));

      final p = e.posten.single;
      expect(p.name, 'Prüfhuhn, gegrillt');
      expect(p.gramm, 140);
      expect(p.werte.kcal, 231);
      expect(p.werte.eiweissG, 43.4);
      expect(p.werte.kohlenhydrateG, 0);
      expect(p.werte.fettG, 5.0);
      expect(p.herkunft, PostenHerkunft.erkannt);
      expect(p.sicher, isTrue);
    });

    test('die übrigen Nährwerte bleiben null, nicht 0', () {
      final w = einzig(antwort([posten()])).werte;
      expect(w.zuckerG, isNull);
      expect(w.ballaststoffeG, isNull);
      expect(w.gesaettigtG, isNull);
      expect(w.wasserMl, isNull);
      expect(w.extra, isEmpty);
    });

    test('mehrere Posten in der Reihenfolge der Antwort', () {
      final a = leseAntwort(
        antwort([
          posten(name: 'Prüfhuhn'),
          posten(
            name: 'Prüfreis',
            grams: 180,
            kcal: 230,
            proteinG: 4.5,
            carbsG: 50,
            fatG: 0.5,
          ),
          posten(
            name: 'Prüföl',
            grams: null,
            kcal: null,
            proteinG: null,
            carbsG: null,
            fatG: null,
            confident: false,
          ),
        ]),
      ) as Erkannt;
      expect(
        [for (final p in a.posten) p.name],
        ['Prüfhuhn', 'Prüfreis', 'Prüföl'],
      );
    });

    test('ohne note ist die Notiz null', () {
      final a = leseAntwort(antwort([posten()])) as Erkannt;
      expect(a.notiz, isNull);
    });

    test('note: null ist die Notiz null', () {
      final json = antwort([posten()])..['note'] = null;
      final a = leseAntwort(json) as Erkannt;
      expect(a.notiz, isNull);
    });

    test('Zahlen als int und als double werden gelesen', () {
      final p = einzig(
        antwort([
          posten(grams: 140.0, kcal: 231.0, proteinG: 43, carbsG: 0.0, fatG: 5),
        ]),
      );
      expect(p.gramm, 140);
      expect(p.werte.kcal, 231);
      expect(p.werte.eiweissG, 43);
      expect(p.werte.kohlenhydrateG, 0);
      expect(p.werte.fettG, 5);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('leseAntwort — null bleibt null (Review Focus 4)', () {
    test('grams: null → gramm null, unsicher, kcal bleibt wie geliefert', () {
      final p = einzig(antwort([posten(grams: null, kcal: 231)]));
      expect(p.gramm, isNull);
      expect(p.sicher, isFalse);
      expect(p.werte.kcal, 231);
      expect(p.werte.eiweissG, 43.4);
    });

    test('alle Nährwerte null → alle null, nicht 0', () {
      final p = einzig(
        antwort([posten(kcal: null, proteinG: null, carbsG: null, fatG: null)]),
      );
      expect(p.werte.kcal, isNull);
      expect(p.werte.eiweissG, isNull);
      expect(p.werte.kohlenhydrateG, isNull);
      expect(p.werte.fettG, isNull);
      expect(p.sicher, isFalse);
    });

    test('ein fehlender Nährwert-Schlüssel ist null, nicht 0', () {
      final json = posten()..remove('fatG');
      final p = einzig(antwort([json]));
      expect(p.werte.fettG, isNull);
      expect(p.werte.kcal, 231);
    });

    test('ein fehlender grams-Schlüssel ist null, nicht 0', () {
      final json = posten()..remove('grams');
      final p = einzig(antwort([json]));
      expect(p.gramm, isNull);
      expect(p.sicher, isFalse);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('leseAntwort — KeinEssen', () {
    test('isFood: false mit leeren items', () {
      expect(
        leseAntwort({'isFood': false, 'title': '', 'items': <Object?>[]}),
        isA<KeinEssen>(),
      );
    });

    test('isFood: false ohne items', () {
      expect(leseAntwort({'isFood': false}), isA<KeinEssen>());
    });

    test('isFood: false mit Posten ist trotzdem KeinEssen', () {
      expect(
        leseAntwort({
          'isFood': false,
          'title': 'Prüfteller',
          'items': [posten()],
        }),
        isA<KeinEssen>(),
      );
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('leseAntwort — Schemaverletzung wirft FormatException', () {
    test('isFood fehlt', () {
      final json = antwort([posten()])..remove('isFood');
      expect(() => leseAntwort(json), throwsFormatException);
    });

    test('isFood ist kein bool', () {
      final json = antwort([posten()])..['isFood'] = 'true';
      expect(() => leseAntwort(json), throwsFormatException);
    });

    test('items ist kein Array', () {
      final json = antwort([posten()])..['items'] = 'Prüfhuhn';
      expect(() => leseAntwort(json), throwsFormatException);
    });

    test('items ist ein Objekt statt eines Arrays', () {
      final json = antwort([posten()])..['items'] = posten();
      expect(() => leseAntwort(json), throwsFormatException);
    });

    test('items fehlt bei isFood: true', () {
      final json = antwort([posten()])..remove('items');
      expect(() => leseAntwort(json), throwsFormatException);
    });

    test('ein Posten ist keine Map', () {
      expect(
        () => leseAntwort(antwort([posten(), 'Prüfhuhn'])),
        throwsFormatException,
      );
    });

    test('ein Posten ohne name', () {
      final json = posten()..remove('name');
      expect(() => leseAntwort(antwort([json])), throwsFormatException);
    });

    test('grams als Text', () {
      expect(
        () => leseAntwort(antwort([posten(grams: '140')])),
        throwsFormatException,
      );
    });

    for (final feld in ['kcal', 'proteinG', 'carbsG', 'fatG']) {
      test('$feld als Text', () {
        final json = posten()..[feld] = '12';
        expect(() => leseAntwort(antwort([json])), throwsFormatException);
      });
    }

    test('negative Gramm', () {
      expect(
        () => leseAntwort(antwort([posten(grams: -20)])),
        throwsFormatException,
      );
    });

    test('confident ist kein bool', () {
      expect(
        () => leseAntwort(antwort([posten(confident: 'yes')])),
        throwsFormatException,
      );
    });

    test('ein kaputter Posten unter guten verwirft die ganze Antwort', () {
      expect(
        () => leseAntwort(antwort([posten(), posten(grams: '80')])),
        throwsFormatException,
      );
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('plausibel', () {
    test('231 kcal bei 43,4 E / 0 K / 5,0 F ist plausibel', () {
      // 4·43,4 + 9·5 = 218,6; Abweichung 12,4 ≤ 0,2·231 + 10 = 56,2.
      expect(
        plausibel(
          const Naehrwerte(
            kcal: 231,
            eiweissG: 43.4,
            kohlenhydrateG: 0,
            fettG: 5.0,
          ),
        ),
        isTrue,
      );
    });

    test('400 kcal bei denselben Makros ist nicht plausibel', () {
      // Abweichung 181,4 > 0,2·400 + 10 = 90.
      expect(
        plausibel(
          const Naehrwerte(
            kcal: 400,
            eiweissG: 43.4,
            kohlenhydrateG: 0,
            fettG: 5.0,
          ),
        ),
        isFalse,
      );
    });

    test('genau auf der Grenze ist plausibel', () {
      // 50 kcal, Grenze 0,2·50 + 10 = 20; 4·17,5 = 70, Abweichung genau 20.
      expect(
        plausibel(
          const Naehrwerte(
            kcal: 50,
            eiweissG: 0,
            kohlenhydrateG: 17.5,
            fettG: 0,
          ),
        ),
        isTrue,
      );
    });

    test('knapp über der Grenze ist nicht plausibel', () {
      // 4·17,6 = 70,4, Abweichung 20,4 > 20.
      expect(
        plausibel(
          const Naehrwerte(
            kcal: 50,
            eiweissG: 0,
            kohlenhydrateG: 17.6,
            fettG: 0,
          ),
        ),
        isFalse,
      );
    });

    test('die Abweichung zählt in beide Richtungen', () {
      // 100 kcal, Grenze 30; Makros 4·17 = 68, Abweichung 32 nach unten.
      expect(
        plausibel(
          const Naehrwerte(
            kcal: 100,
            eiweissG: 0,
            kohlenhydrateG: 17,
            fettG: 0,
          ),
        ),
        isFalse,
      );
      // Makros 4·18 = 72, Abweichung 28 nach unten.
      expect(
        plausibel(
          const Naehrwerte(
            kcal: 100,
            eiweissG: 0,
            kohlenhydrateG: 18,
            fettG: 0,
          ),
        ),
        isTrue,
      );
    });

    test('Fett zählt 9, Eiweiß und Kohlenhydrate je 4', () {
      // 90 kcal aus 10 g Fett: plausibel. Würde Fett mit 4 gezählt, wären
      // es 40 und die Abweichung 50 > 28.
      expect(
        plausibel(
          const Naehrwerte(kcal: 90, eiweissG: 0, kohlenhydrateG: 0, fettG: 10),
        ),
        isTrue,
      );
      // 40 kcal aus 10 g Eiweiß bzw. 10 g Kohlenhydraten.
      expect(
        plausibel(
          const Naehrwerte(kcal: 40, eiweissG: 10, kohlenhydrateG: 0, fettG: 0),
        ),
        isTrue,
      );
      expect(
        plausibel(
          const Naehrwerte(kcal: 40, eiweissG: 0, kohlenhydrateG: 10, fettG: 0),
        ),
        isTrue,
      );
    });

    test('alles 0 ist plausibel — null ist eine Angabe', () {
      expect(
        plausibel(
          const Naehrwerte(kcal: 0, eiweissG: 0, kohlenhydrateG: 0, fettG: 0),
        ),
        isTrue,
      );
    });

    const vollstaendig = Naehrwerte(
      kcal: 231,
      eiweissG: 43.4,
      kohlenhydrateG: 0,
      fettG: 5.0,
    );

    test('ohne kcal nicht plausibel', () {
      expect(
        plausibel(
          const Naehrwerte(eiweissG: 43.4, kohlenhydrateG: 0, fettG: 5.0),
        ),
        isFalse,
      );
    });

    test('ohne Eiweiß nicht plausibel', () {
      expect(
        plausibel(const Naehrwerte(kcal: 231, kohlenhydrateG: 0, fettG: 5.0)),
        isFalse,
      );
    });

    test('ohne Kohlenhydrate nicht plausibel', () {
      expect(
        plausibel(const Naehrwerte(kcal: 231, eiweissG: 43.4, fettG: 5.0)),
        isFalse,
      );
    });

    test('ohne Fett nicht plausibel', () {
      expect(
        plausibel(
          const Naehrwerte(kcal: 231, eiweissG: 43.4, kohlenhydrateG: 0),
        ),
        isFalse,
      );
    });

    test('die übrigen Felder spielen keine Rolle', () {
      expect(plausibel(vollstaendig), isTrue);
      expect(
        plausibel(
          const Naehrwerte(
            kcal: 231,
            eiweissG: 43.4,
            kohlenhydrateG: 0,
            fettG: 5.0,
            zuckerG: 80,
            ballaststoffeG: 30,
          ),
        ),
        isTrue,
      );
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('sicher', () {
    test('confident, mit Gramm, mit kcal, plausibel → sicher', () {
      expect(einzig(antwort([posten()])).sicher, isTrue);
    });

    test('unplausibel ist unsicher, obwohl confident: true', () {
      final p = einzig(antwort([posten(kcal: 400, confident: true)]));
      expect(p.sicher, isFalse);
    });

    test('confident: false ist unsicher, obwohl plausibel', () {
      final p = einzig(antwort([posten(confident: false)]));
      expect(p.sicher, isFalse);
    });

    test('ohne kcal unsicher', () {
      final p = einzig(antwort([posten(kcal: null)]));
      expect(p.sicher, isFalse);
    });

    test('ohne einen Makro unsicher (nicht plausibel)', () {
      final p = einzig(antwort([posten(carbsG: null)]));
      expect(p.sicher, isFalse);
    });

    test('ohne Gramm unsicher, obwohl der Rest stimmt', () {
      final p = einzig(antwort([posten(grams: null)]));
      expect(p.sicher, isFalse);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('mitMenge', () {
    const geschaetzt = SchaetzPosten(
      name: 'Prüfhuhn, gegrillt',
      gramm: 140,
      werte: Naehrwerte(
        kcal: 231,
        eiweissG: 43.4,
        kohlenhydrateG: 0,
        fettG: 5.0,
      ),
      sicher: true,
      herkunft: PostenHerkunft.erkannt,
    );

    test('140 g / 231 kcal auf 165 g → 272,25 kcal, „von dir"', () {
      final p = mitMenge(geschaetzt, 165);
      expect(p.gramm, 165);
      expect(p.werte.kcal, closeTo(272.25, 1e-9));
      expect(p.herkunft, PostenHerkunft.vonDir);
      expect(p.name, 'Prüfhuhn, gegrillt');
    });

    test('alle Nährwerte skalieren mit, 0 bleibt 0, null bleibt null', () {
      final p = mitMenge(geschaetzt, 165);
      expect(p.werte.eiweissG, closeTo(43.4 * 165 / 140, 1e-9));
      expect(p.werte.fettG, closeTo(5.0 * 165 / 140, 1e-9));
      expect(p.werte.kohlenhydrateG, 0);
      expect(p.werte.zuckerG, isNull);
      expect(p.werte.ballaststoffeG, isNull);
    });

    test('ein fehlender Nährwert bleibt fehlend', () {
      const ohneFett = SchaetzPosten(
        name: 'Prüfreis',
        gramm: 200,
        werte: Naehrwerte(kcal: 260, eiweissG: 5, kohlenhydrateG: 56),
        sicher: false,
        herkunft: PostenHerkunft.erkannt,
      );
      final p = mitMenge(ohneFett, 100);
      expect(p.werte.kcal, closeTo(130, 1e-9));
      expect(p.werte.eiweissG, closeTo(2.5, 1e-9));
      expect(p.werte.kohlenhydrateG, closeTo(28, 1e-9));
      expect(p.werte.fettG, isNull);
    });

    test('ohne geschätzte Menge bleiben die Nährwerte null', () {
      const ohneMenge = SchaetzPosten(
        name: 'Prüfsoße',
        gramm: null,
        werte: Naehrwerte(),
        sicher: false,
        herkunft: PostenHerkunft.erkannt,
      );
      final p = mitMenge(ohneMenge, 30);
      expect(p.gramm, 30);
      expect(p.werte.kcal, isNull);
      expect(p.werte.eiweissG, isNull);
      expect(p.werte.kohlenhydrateG, isNull);
      expect(p.werte.fettG, isNull);
      expect(p.herkunft, PostenHerkunft.vonDir);
    });

    test('ohne geschätzte Menge wird geliefertes kcal nicht mitgenommen', () {
      // Die KI nannte 120 kcal, aber zu keiner Menge. 120 kcal unter Tims
      // 30 g zeigte eine Zahl, die zu einer anderen Menge gehört.
      const ohneMenge = SchaetzPosten(
        name: 'Prüfsoße',
        gramm: null,
        werte: Naehrwerte(kcal: 120, eiweissG: 1, kohlenhydrateG: 4, fettG: 11),
        sicher: false,
        herkunft: PostenHerkunft.erkannt,
      );
      final p = mitMenge(ohneMenge, 30);
      expect(p.gramm, 30);
      expect(p.werte.kcal, isNull);
      expect(p.werte.eiweissG, isNull);
      expect(p.werte.kohlenhydrateG, isNull);
      expect(p.werte.fettG, isNull);
    });

    test('0 g ergeben 0, nicht null', () {
      final p = mitMenge(geschaetzt, 0);
      expect(p.gramm, 0);
      expect(p.werte.kcal, 0);
      expect(p.werte.eiweissG, 0);
      expect(p.werte.fettG, 0);
    });

    test('eine schon geänderte Zeile wird vom neuen Stand aus skaliert', () {
      final einmal = mitMenge(geschaetzt, 280);
      final zweimal = mitMenge(einmal, 70);
      expect(zweimal.werte.kcal, closeTo(115.5, 1e-9));
      expect(zweimal.herkunft, PostenHerkunft.vonDir);
    });

    test('der ursprüngliche Posten bleibt unverändert', () {
      mitMenge(geschaetzt, 165);
      expect(geschaetzt.gramm, 140);
      expect(geschaetzt.werte.kcal, 231);
      expect(geschaetzt.herkunft, PostenHerkunft.erkannt);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('uebernommen', () {
    test('lässt unsichere, unberührte Posten ohne Menge weg, behält „von '
        'dir"', () {
      final sicher = sp('Prüfhuhn');
      final unsicherUnberuehrt = sp('Prüföl', gramm: null, sicher: false);
      final unsicherVonDir = sp(
        'Prüfsoße',
        sicher: false,
        herkunft: PostenHerkunft.vonDir,
      );
      expect(uebernommen([sicher, unsicherUnberuehrt, unsicherVonDir]), [
        sicher,
        unsicherVonDir,
      ]);
    });

    test('ein ergänzter Posten ist übernommen, auch wenn unsicher', () {
      final ergaenzt = sp(
        'Prüfbrot',
        sicher: false,
        herkunft: PostenHerkunft.ergaenzt,
      );
      expect(uebernommen([ergaenzt]), [ergaenzt]);
    });

    test('ein Posten mit grams: null aus der Antwort ist nicht übernommen', () {
      // Review Focus 4.
      final a = leseAntwort(
        antwort([
          posten(name: 'Prüfhuhn'),
          posten(name: 'Prüföl', grams: null, confident: false),
        ]),
      ) as Erkannt;
      expect([for (final p in uebernommen(a.posten)) p.name], ['Prüfhuhn']);
    });

    test('die Reihenfolge bleibt', () {
      // #407: C fehlt, weil es ohne Menge ist — mit Menge wäre es dabei.
      final a = sp('A');
      final b = sp('B', sicher: false, herkunft: PostenHerkunft.vonDir);
      final c = sp('C', gramm: null, sicher: false);
      final d = sp('D', sicher: false);
      final e = sp('E');
      expect(uebernommen([a, b, c, d, e]), [a, b, d, e]);
    });

    test('leer bleibt leer', () {
      expect(uebernommen(const []), isEmpty);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // #407, Tims Meldung vom 07.11.2026: Ist die KI bei einem Posten
  // unsicher, soll er ihn trotzdem direkt buchen können, ohne erst die
  // Menge anzufassen. Ein unsicherer Posten **mit Menge** ist übernommen
  // und bleibt als unsicher markiert; einer **ohne Menge** nicht.
  group('uebernommen — unsicher mit Menge (#407)', () {
    test('ein unsicherer, unberührter Posten mit Menge ist übernommen', () {
      final unsicher = sp('Prüföl', gramm: 15, sicher: false);
      expect(uebernommen([unsicher]), [unsicher]);
    });

    test('er bleibt unsicher — uebernommen ändert keinen Posten', () {
      final unsicher = sp('Prüföl', gramm: 15, sicher: false);
      final p = uebernommen([unsicher]).single;
      expect(p.sicher, isFalse);
      expect(p.herkunft, PostenHerkunft.erkannt);
      expect(p, unsicher);
    });

    test('ein unsicherer, unberührter Posten ohne Menge bleibt draußen', () {
      final ohneMenge = sp('Prüfsoße', gramm: null, sicher: false);
      expect(uebernommen([ohneMenge]), isEmpty);
    });

    test('aus der Antwort: confident: false mit Menge ist übernommen', () {
      final a = leseAntwort(
        antwort([
          posten(name: 'Prüfhuhn'),
          posten(name: 'Prüfreis', confident: false),
        ]),
      ) as Erkannt;
      final p = a.posten[1];
      expect(p.sicher, isFalse, reason: 'Voraussetzung: unsicher');
      expect(
        [for (final p in uebernommen(a.posten)) p.name],
        ['Prüfhuhn', 'Prüfreis'],
      );
    });

    test('aus der Antwort: unplausibel mit Menge ist übernommen', () {
      final a = leseAntwort(
        antwort([posten(name: 'Prüfdressing', kcal: 400)]),
      ) as Erkannt;
      expect(a.posten.single.sicher, isFalse, reason: 'Voraussetzung');
      expect(uebernommen(a.posten), a.posten);
    });

    test('aus der Antwort: mit Menge, aber ohne kcal ist übernommen — die '
        'kcal bleiben null', () {
      final a = leseAntwort(
        antwort([posten(name: 'Prüfbrot', kcal: null)]),
      ) as Erkannt;
      final p = uebernommen(a.posten).single;
      expect(p.sicher, isFalse);
      expect(p.werte.kcal, isNull, reason: 'null bleibt null, nie 0');
    });

    test('ein gemischter Teller: alle mit Menge, keiner ohne', () {
      final a = leseAntwort(
        antwort([
          posten(name: 'Prüfhuhn'),
          posten(name: 'Prüfsoße', grams: null, confident: false),
          posten(name: 'Prüfreis', confident: false),
          posten(name: 'Prüföl', grams: null, kcal: null),
          posten(name: 'Prüfdressing', kcal: 400),
        ]),
      ) as Erkannt;
      expect(
        [for (final p in uebernommen(a.posten)) p.name],
        ['Prüfhuhn', 'Prüfreis', 'Prüfdressing'],
      );
    });

    test('idempotent: zweimal gefiltert ist einmal gefiltert', () {
      final posten = [
        sp('A'),
        sp('B', gramm: null, sicher: false),
        sp('C', sicher: false),
        sp('D', gramm: null, sicher: false, herkunft: PostenHerkunft.ergaenzt),
      ];
      expect(uebernommen(uebernommen(posten)), uebernommen(posten));
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('SchaetzPosten', () {
    test('Wertgleichheit über alle Felder', () {
      expect(sp('Prüfhuhn'), equals(sp('Prüfhuhn')));
      expect(sp('Prüfhuhn').hashCode, sp('Prüfhuhn').hashCode);
      expect(sp('Prüfhuhn'), isNot(sp('Prüfreis')));
      expect(sp('Prüfhuhn'), isNot(sp('Prüfhuhn', gramm: 120)));
      expect(sp('Prüfhuhn'), isNot(sp('Prüfhuhn', gramm: null)));
      expect(
        sp('Prüfhuhn'),
        isNot(sp('Prüfhuhn', werte: const Naehrwerte(kcal: 101))),
      );
      expect(sp('Prüfhuhn'), isNot(sp('Prüfhuhn', sicher: false)));
      expect(
        sp('Prüfhuhn'),
        isNot(sp('Prüfhuhn', herkunft: PostenHerkunft.vonDir)),
      );
    });
  });
}
