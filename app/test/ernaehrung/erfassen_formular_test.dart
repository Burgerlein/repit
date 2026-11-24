import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/ernaehrung_repository.dart';
import 'package:repit/data/lebensmittel_repository.dart';
import 'package:repit/ernaehrung/erfassen_formular.dart';

/// Tests für die **Rechnung hinter den beiden Blättern** des
/// Eintragwegs (#285, zugeschnitten): „Lebensmittel anlegen" und
/// „Portion wählen" / „Eintrag ändern".
///
/// Ohne Widget und ohne Datenbank — hier steht, was gerechnet wird. Die
/// Verdrahtung prüft `erfassen_rundweg_test.dart`, die Oberfläche
/// `erfassen_view_test.dart`.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung**
/// (`CLAUDE.md`). Diese Datei darf ausgeführt, aber nicht verändert
/// werden.
///
/// Vorlage ist `docs/screens/screens/erfassen.js`, Zustände `anlegen`,
/// `produkt` und `aendern`, dazu
/// `docs/superpowers/specs/2026-11-03-ernaehrung-design.md`, Abschnitte
/// „Welche Mahlzeit — und auf welchem Tag" und „Eingefrorene Nährwerte".
///
/// ## Was diese Tests verbindlich vorgeben
///
/// Neu in `lib/ernaehrung/erfassen_formular.dart`:
///
/// ```dart
/// /// Liest ein Eingabefeld als nichtnegative Zahl.
/// ///
/// /// **Drei Fälle in zwei Feldern:** leer → `(wert: null, lesbar: true)`,
/// /// lesbar → `(wert: 13.5, lesbar: true)`, unlesbar →
/// /// `(wert: null, lesbar: false)`. Leer ist kein Fehler, unlesbar
/// /// schon — und beide ergeben `null`, deshalb reicht das Feld allein
/// /// nicht.
/// ({double? wert, bool lesbar}) liesZahl(String text);
///
/// /// Der Zustand des Blattes „Lebensmittel anlegen".
/// @immutable
/// class AnlegenFormular {
///   const AnlegenFormular({
///     this.name = '',
///     this.fluessig = false,
///     this.kcal = '',
///     this.eiweissG = '',
///     this.kohlenhydrateG = '',
///     this.fettG = '',
///     this.zuckerG = '',
///     this.gesaettigtG = '',
///     this.ballaststoffeG = '',
///   });
///   AnlegenFormular mit({String? name, bool? fluessig, String? kcal,
///       String? eiweissG, String? kohlenhydrateG, String? fettG,
///       String? zuckerG, String? gesaettigtG, String? ballaststoffeG});
///   bool get kannSichern;
///   LebensmittelVorlage? alsVorlage();
/// }
///
/// /// Der Zustand des Buchungsblattes — „Portion wählen" und „Eintrag
/// /// ändern" sind **derselbe** Zustand, einmal ohne und einmal mit
/// /// [bearbeitetId].
/// @immutable
/// class BuchungsFormular {
///   const BuchungsFormular({
///     this.lebensmittelId,
///     required this.name,
///     required this.je100g,
///     required this.tagesSchluessel,
///     required this.mengeText,
///     required this.mahlzeit,
///     required this.minutenSeitMitternacht,
///     this.fluessig = false,
///     this.bearbeitetId,
///   });
///   factory BuchungsFormular.neu({
///     required LebensmittelVorlage vorlage,
///     required String tagesSchluessel,
///     required DateTime jetzt,
///   });
///   factory BuchungsFormular.fuer(Eintrag eintrag);
///   BuchungsFormular mitMenge(String text);
///   BuchungsFormular mitMahlzeit(Mahlzeit mahlzeit);
///   BuchungsFormular mitUhrzeit(int minutenSeitMitternacht);
///   double? get mengeG;
///   bool get kannBuchen;
///   Naehrwerte get naehrwerte;
///   DateTime get zeitpunkt;
///   Eintrag alsEintrag();
/// }
/// ```
///
/// ## Entscheidungen des Test-Agenten
///
/// **Keine davon ist mit Tim abgestimmt oder freigegeben** — jede mit
/// Begründung, weil Entwurf und Spec sie offenlassen.
///
/// 1. **Die Felder sind Text, nicht Zahlen.** Was getippt wird, ist Text;
///    „13," ist ein Zwischenzustand beim Tippen und kein Fehler. Ein
///    Formular aus `double?` müsste den Zwischenzustand entweder
///    wegwerfen oder doppelt führen.
/// 2. **`liesZahl` liest nur nichtnegative Zahlen.** `-5 g Fett` gibt es
///    nicht. Die Prüfung steht an **einer** Stelle statt einmal im
///    Formular und einmal im Blatt — dieselbe Haltung wie bei
///    `alsMesswert` (`CLAUDE.md`, Hausregel 1).
/// 3. **Ein unlesbares freiwilliges Feld sperrt „Sichern" ebenfalls.**
///    Der Entwurf sagt nur „Pflicht sind Name und Kalorien". Ein Blatt,
///    das bei unlesbarem Zucker sichert und den Zucker dabei fallen
///    lässt, wirft eine Eingabe lautlos weg — und der Nutzer sieht
///    hinterher ein Lebensmittel ohne Zuckerangabe und hält es für seine
///    eigene Nachlässigkeit.
/// 4. **`mitMahlzeit` zieht die Uhrzeit mit, `mitUhrzeit` nicht die
///    Mahlzeit.** Die Mahlzeit zu wechseln ist die grobe Geste, die
///    Uhrzeit zu setzen die feine; die vier Mitten liegen je in ihrem
///    eigenen Fenster (`Mahlzeitfenster.mitteInMinuten`), und ohne das
///    Mitziehen trüge ein umgehängtes Frühstück die Uhrzeit 19:00. Dass
///    `mitUhrzeit` die Mahlzeit **stehen lässt**, ist die Gegenrichtung
///    und gewollt: Die Mahlzeit steht am Eintrag, nicht an seiner
///    Uhrzeit (`ernaehrung_provider.dart`, `_zeilen`).
/// 5. **`kannBuchen` verlangt eine Menge größer als 0.** Die Portion ist
///    die eigentliche Frage dieses Blattes (`erfassen.js`); 0 g ist keine
///    Portion. Das ist **kein** Widerspruch zu „eine gewogene 0 bleibt 0"
///    — das gilt für Nährwerte, nicht für die Menge, und die Datenschicht
///    lässt `0` weiterhin durch.
/// 6. **Die Vorgabemenge ist 100 g**, nicht 250 wie im Entwurfsbild. Die
///    Nährwerte stehen je 100 g da; 100 ist die Menge, bei der die
///    gezeigten Zahlen genau die eingegebenen sind, und damit die
///    einzige, die nichts behauptet. (Die 250 im Entwurf sind eine
///    Beispielzahl — das Board sagt das über alle seine Zahlen.)
/// 7. **Der Tag ist im Blatt nicht änderbar.** Er ist der offene Tag.
///    Dass der Entwurf im Zustand `produkt` eine Zeile „Tag" zeigt und im
///    Zustand `aendern` keine, ist ein offener Punkt; er ist an den
///    Koordinator gemeldet und steht in diesem Zuschnitt nicht drin.
///
/// ## Die Uhrzeit eines neuen Blattes (#328)
///
/// **Geändert vom Test-Agenten von #328, nicht vom Implementierenden.**
/// Anlass ist Tims Meldung vom 04.11.2026 vom Gerät: Nach dem Scannen
/// öffnet sich das Buchungsblatt, und „die Uhrzeit stimmt nicht". Bis
/// dahin setzte `BuchungsFormular.neu` die Uhrzeit **immer** auf die Mitte
/// des Mahlzeitfensters.
///
/// **Tims Entscheidung vom 04.11.2026**, wörtlich: „lass uns immer die
/// uhrzeit nehmen an der ich es tracke, man kann es ja manuell
/// umstellen". Daraus:
///
/// - `minutenSeitMitternacht` ist **immer** die **Berliner Wanduhrzeit
///   von `jetzt`** — Stunde·60 + Minute, Sekunden abgeschnitten. Auch auf
///   einem geblätterten Tag, in beide Richtungen.
/// - Die Mahlzeit kommt wie bisher aus `jetzt`.
/// - Nach Mitternacht gilt dasselbe: 01:30 Berliner Zeit ist Abend, und
///   im Blatt steht 01:30 — auf dem offenen Tag, auch wenn das der Vortag
///   ist.
/// - `mitMahlzeit` zieht weiter auf die Mitte der neuen Mahlzeit,
///   `mitUhrzeit` ist unverändert.
///
/// Die Begründung der Spec („Welche Mahlzeit — und auf welchem Tag") gilt
/// damit für die **Uhrzeit** nicht mehr, für den **Tag** weiter: Gebucht
/// wird auf den offenen Tag, nicht auf den von „jetzt".
///
/// Dass die Sekunden **abgeschnitten** und nicht gerundet werden, steht im
/// Auftrag zu #328, nicht in Tims Satz; die Tests dazu hat Tim nicht
/// gesehen. Was geschieht, wenn `mitMahlzeit` dieselbe Mahlzeit noch
/// einmal wählt, ist offen und bewusst nicht getestet.
///
/// ## Nachtrag: Tagesgrenze (#456 unter #375, löst #373)
///
/// **Geändert vom Test-Agenten von #456, nicht vom Implementierenden.**
/// Die Uhrzeit im Blatt bleibt die Berliner Wanduhrzeit von „jetzt“ (#328
/// gilt weiter). Geändert hat sich, **auf welchen Kalendertag** sie fällt:
/// `BuchungsFormular.zeitpunkt` rechnet seit #456 über `zeitpunktImTag`
/// (Spec `docs/superpowers/specs/2026-11-10-tagesgrenze-design.md`, V14,
/// von Tim am 10.11.2026 übernommen). Ohne Grund gilt `normal`: **vor
/// 04:00 der Folgetag des offenen Tages**, sonst der Tag selbst.
///
/// Drei Fälle der Gruppe „Im Blatt steht die Uhrzeit …“ verlangten noch
/// die Wanduhrzeit auf dem offenen Tag selbst und sind nachgezogen:
///
/// - „01:30, offen ist der Kalendertag von jetzt“: 01:30 auf dem 14.07.
///   ist jetzt der **15.07.** 01:30.
/// - „01:30, offen ist der Vortag“: Das war genau der Fehler aus #373 (Mo
///   01:30 statt Di 01:30). Jetzt steht der Eintrag auf dem Vortag mit dem
///   Zeitpunkt „jetzt“.
/// - „die Uhrzeit ist die Berliner, nicht die UTC-Uhrzeit“: zeigt weiter,
///   dass 00:30 Berliner Zeit zählt und nicht 22:30 UTC — in den Minuten
///   und im Zeitpunkt, der jetzt auf den Folgetag fällt.
///
/// Mahlzeit und Minuten der drei Fälle sind unverändert.
///
/// Zahlen und Namen in dieser Datei sind erfunden.
void main() {
  // Dienstag, 14.07.2026, 12:00 Berliner Zeit (MESZ, +2).
  final mittags = DateTime.utc(2026, 7, 14, 10);
  const heute = '2026-07-14';
  const montag = '2026-07-13';

  const haferflocken = Naehrwerte.je100g(
    kcal: 372,
    eiweissG: 13.5,
    kohlenhydrateG: 58.7,
    fettG: 7,
    ballaststoffeG: 10,
  );

  const hafer = LebensmittelVorlage(
    id: 42,
    name: 'Haferflocken kernig',
    je100g: haferflocken,
  );

  // ═════════════════════════════════════════════════════════════════════
  group('liesZahl', () {
    test('ein leeres Feld ist kein Fehler und kein Wert', () {
      expect(liesZahl(''), (wert: null, lesbar: true));
      expect(liesZahl('   '), (wert: null, lesbar: true));
    });

    test('Komma und Punkt gelten beide als Dezimaltrennzeichen', () {
      expect(liesZahl('13,5').wert, 13.5);
      expect(liesZahl('13.5').wert, 13.5);
      expect(liesZahl('372').wert, 372);
    });

    test('Leerzeichen am Rand stören nicht', () {
      expect(liesZahl('  372  ').wert, 372);
    });

    test('ein angefangenes Dezimaltrennzeichen ist lesbar', () {
      // „13," entsteht beim Tippen. Es als Fehler zu behandeln ließe den
      // Sichern-Knopf bei jedem zweiten Tastendruck aufblitzen.
      expect(liesZahl('13,'), (wert: 13.0, lesbar: true));
    });

    test('eine 0 ist ein Wert, kein leeres Feld', () {
      expect(liesZahl('0'), (wert: 0.0, lesbar: true));
    });

    test('Unsinn ist unlesbar — und liefert keinen Wert', () {
      for (final text in ['abc', '1,2,3', '12 g', '--3', '1e', ',']) {
        expect(liesZahl(text), (wert: null, lesbar: false), reason: text);
      }
    });

    test('negative Zahlen sind unlesbar — es gibt keine -5 g Fett', () {
      expect(liesZahl('-5'), (wert: null, lesbar: false));
      expect(liesZahl('-0,5'), (wert: null, lesbar: false));
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Sichern ist gesperrt, bis Name und Kalorien dastehen', () {
    test('ein frisches Formular kann nicht sichern', () {
      expect(const AnlegenFormular().kannSichern, isFalse);
    });

    test('der Name allein reicht nicht', () {
      expect(
        const AnlegenFormular().mit(name: 'Haferflocken').kannSichern,
        isFalse,
      );
    });

    test('die Kalorien allein reichen nicht', () {
      expect(const AnlegenFormular().mit(kcal: '372').kannSichern, isFalse);
    });

    test('beides zusammen reicht', () {
      expect(
        const AnlegenFormular()
            .mit(name: 'Haferflocken', kcal: '372')
            .kannSichern,
        isTrue,
      );
    });

    test('ein Name aus lauter Leerzeichen ist kein Name', () {
      expect(
        const AnlegenFormular().mit(name: '   ', kcal: '372').kannSichern,
        isFalse,
      );
    });

    test('unlesbare Kalorien sperren', () {
      expect(
        const AnlegenFormular()
            .mit(name: 'Haferflocken', kcal: 'viele')
            .kannSichern,
        isFalse,
      );
    });

    test('0 Kalorien sperren nicht — Mineralwasser hat keine', () {
      expect(
        const AnlegenFormular()
            .mit(name: 'Mineralwasser', kcal: '0')
            .kannSichern,
        isTrue,
      );
    });

    test('ein unlesbares freiwilliges Feld sperrt ebenfalls', () {
      final grund = const AnlegenFormular().mit(
        name: 'Haferflocken',
        kcal: '372',
      );
      expect(grund.kannSichern, isTrue);

      expect(grund.mit(zuckerG: 'wenig').kannSichern, isFalse);
      expect(grund.mit(eiweissG: '1,2,3').kannSichern, isFalse);
      expect(grund.mit(ballaststoffeG: '-2').kannSichern, isFalse);
    });

    test('ein leer gelassenes freiwilliges Feld sperrt nicht', () {
      expect(
        const AnlegenFormular()
            .mit(name: 'Haferflocken', kcal: '372', zuckerG: '')
            .kannSichern,
        isTrue,
      );
    });

    test('Komma und Punkt öffnen gleichermaßen', () {
      expect(
        const AnlegenFormular()
            .mit(name: 'Haferflocken', kcal: '372,5')
            .kannSichern,
        isTrue,
      );
      expect(
        const AnlegenFormular()
            .mit(name: 'Haferflocken', kcal: '372.5')
            .kannSichern,
        isTrue,
      );
    });

    test('alsVorlage ist null, solange nicht gesichert werden kann', () {
      expect(const AnlegenFormular().alsVorlage(), isNull);
      expect(
        const AnlegenFormular().mit(name: 'Haferflocken').alsVorlage(),
        isNull,
      );
      expect(
        const AnlegenFormular()
            .mit(name: 'Haferflocken', kcal: '372', fettG: 'viel')
            .alsVorlage(),
        isNull,
      );
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Was das Blatt „anlegen" anlegt', () {
    test('trägt die Nährwerte je 100 g, genau wie eingetippt', () {
      final vorlage = const AnlegenFormular()
          .mit(
            name: 'Haferflocken kernig',
            kcal: '372',
            eiweissG: '13,5',
            kohlenhydrateG: '58,7',
            fettG: '7',
            ballaststoffeG: '10',
          )
          .alsVorlage()!;

      expect(vorlage.name, 'Haferflocken kernig');
      expect(vorlage.je100g, haferflocken);
    });

    test('schneidet Leerzeichen am Namen ab', () {
      final vorlage = const AnlegenFormular()
          .mit(name: '  Haferflocken kernig  ', kcal: '372')
          .alsVorlage()!;

      expect(vorlage.name, 'Haferflocken kernig');
    });

    test('ein leer gelassenes Feld bleibt null, nicht 0', () {
      final vorlage = const AnlegenFormular()
          .mit(name: 'Haferflocken kernig', kcal: '372')
          .alsVorlage()!;

      expect(vorlage.je100g.kcal, 372);
      expect(vorlage.je100g.eiweissG, isNull);
      expect(vorlage.je100g.kohlenhydrateG, isNull);
      expect(vorlage.je100g.fettG, isNull);
      expect(vorlage.je100g.zuckerG, isNull);
      expect(vorlage.je100g.gesaettigtG, isNull);
      expect(vorlage.je100g.ballaststoffeG, isNull);
      expect(vorlage.je100g.wasserMl, isNull);
    });

    test('eine getippte 0 bleibt 0 — „zuckerfrei" ist eine Angabe', () {
      final vorlage = const AnlegenFormular()
          .mit(name: 'Hafer', kcal: '372', zuckerG: '0')
          .alsVorlage()!;

      expect(vorlage.je100g.zuckerG, 0);
    });

    test('trägt noch keinen Schlüssel — den vergibt die Datenbank', () {
      final vorlage = const AnlegenFormular()
          .mit(name: 'Hafer', kcal: '372')
          .alsVorlage()!;

      expect(vorlage.id, isNull);
      expect(vorlage.zuletztBenutzt, isNull);
    });

    test(
      'der Bezug steht vorgabemäßig auf je 100 g, nicht auf Flüssigkeit',
      () {
        final fest = const AnlegenFormular()
            .mit(name: 'Hafer', kcal: '372')
            .alsVorlage()!;
        final getraenk = const AnlegenFormular()
            .mit(name: 'Haferdrink', kcal: '59', fluessig: true)
            .alsVorlage()!;

        expect(fest.fluessig, isFalse);
        expect(getraenk.fluessig, isTrue);
      },
    );

    test('mit ändert genau ein Feld und lässt die anderen stehen', () {
      final grund = const AnlegenFormular().mit(
        name: 'Hafer',
        kcal: '372',
        eiweissG: '13,5',
      );
      final geaendert = grund.mit(kcal: '370');

      expect(geaendert.name, 'Hafer');
      expect(geaendert.eiweissG, '13,5');
      expect(geaendert.kcal, '370');
      // Und das Ursprungsformular bleibt, wie es war.
      expect(grund.kcal, '372');
    });

    test('mit kann ein Feld auch wieder leeren', () {
      final geleert = const AnlegenFormular()
          .mit(name: 'Hafer', kcal: '372', zuckerG: '5')
          .mit(zuckerG: '');

      expect(geleert.zuckerG, '');
      expect(geleert.alsVorlage()!.je100g.zuckerG, isNull);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Die Mahlzeit kommt aus der Uhrzeit, ist aber änderbar', () {
    BuchungsFormular um(int stundeUtc, int minuteUtc) => BuchungsFormular.neu(
      vorlage: hafer,
      tagesSchluessel: heute,
      jetzt: DateTime.utc(2026, 7, 14, stundeUtc, minuteUtc),
    );

    test('morgens um 09:00 Berliner Zeit ist Frühstück', () {
      expect(um(7, 0).mahlzeit, Mahlzeit.fruehstueck);
    });

    test('mittags um 12:00 Berliner Zeit ist Mittag', () {
      expect(um(10, 0).mahlzeit, Mahlzeit.mittag);
    });

    test('um 16:00 Berliner Zeit ist Snack', () {
      expect(um(14, 0).mahlzeit, Mahlzeit.snack);
    });

    test('abends um 20:00 Berliner Zeit ist Abendessen', () {
      expect(um(18, 0).mahlzeit, Mahlzeit.abend);
    });

    test('der Abend umschließt Mitternacht: 01:30 gehört zum Abend davor', () {
      // 23:30 UTC am 13.07. ist in Berlin der 14.07., 01:30 — und damit
      // Abendessen, nicht Snack.
      final formular = BuchungsFormular.neu(
        vorlage: hafer,
        tagesSchluessel: heute,
        jetzt: DateTime.utc(2026, 7, 13, 23, 30),
      );

      expect(formular.mahlzeit, Mahlzeit.abend);
    });

    test(
      'die Uhrzeit wird über die Berliner Wanduhr gelesen, nicht über UTC',
      () {
        // 22:30 UTC ist im Juli in Berlin schon 00:30 — Abend, nicht Snack.
        final sommer = BuchungsFormular.neu(
          vorlage: hafer,
          tagesSchluessel: heute,
          jetzt: DateTime.utc(2026, 7, 14, 22, 30),
        );
        expect(sommer.mahlzeit, Mahlzeit.abend);

        // Dieselbe UTC-Stunde im Januar ist in Berlin 23:30 — auch Abend,
        // aber über einen anderen Versatz. Der Gegenprobenfall liegt um
        // 09:30 UTC: Januar 10:30 (Frühstück), Juli 11:30 (Mittag).
        final winter = BuchungsFormular.neu(
          vorlage: hafer,
          tagesSchluessel: '2026-01-14',
          jetzt: DateTime.utc(2026, 1, 14, 9, 30),
        );
        expect(winter.mahlzeit, Mahlzeit.fruehstueck);

        final juli = BuchungsFormular.neu(
          vorlage: hafer,
          tagesSchluessel: heute,
          jetzt: DateTime.utc(2026, 7, 14, 9, 30),
        );
        expect(juli.mahlzeit, Mahlzeit.mittag);
      },
    );

    test('mitMahlzeit hängt um und zieht die Uhrzeit von „jetzt" auf die '
        'neue Mitte', () {
      // Heute steht „jetzt" im Blatt (#328): 12:00, nicht die Mittagsmitte
      // 12:30.
      final formular = um(10, 0);
      expect(formular.mahlzeit, Mahlzeit.mittag);
      expect(formular.minutenSeitMitternacht, 12 * 60);

      final umgehaengt = formular.mitMahlzeit(Mahlzeit.fruehstueck);
      expect(umgehaengt.mahlzeit, Mahlzeit.fruehstueck);
      expect(umgehaengt.minutenSeitMitternacht, 8 * 60);
    });

    test(
      'mitUhrzeit lässt die Mahlzeit stehen, auch über die Fenstergrenze',
      () {
        // Tim hängt sein spätes Frühstück auf 11:30 — es bleibt Frühstück.
        // Die Mahlzeit steht am Eintrag, nicht an seiner Uhrzeit.
        final formular = um(7, 0).mitUhrzeit(11 * 60 + 30);

        expect(formular.mahlzeit, Mahlzeit.fruehstueck);
        expect(formular.minutenSeitMitternacht, 11 * 60 + 30);
      },
    );
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Im Blatt steht die Uhrzeit, zu der getrackt wird — auf jedem Tag '
      '(#328)', () {
    test('heute im Sommer: die Berliner Wanduhrzeit von „jetzt"', () {
      // 10:05 UTC am 14.07.2026 ist in Berlin 12:05 (MESZ, +2).
      final formular = BuchungsFormular.neu(
        vorlage: hafer,
        tagesSchluessel: heute,
        jetzt: DateTime.utc(2026, 7, 14, 10, 5),
      );

      expect(formular.mahlzeit, Mahlzeit.mittag);
      expect(formular.minutenSeitMitternacht, 12 * 60 + 5);
      expect(formular.zeitpunkt, DateTime.utc(2026, 7, 14, 10, 5));
    });

    test('heute im Winter: dieselbe Regel über den anderen Versatz', () {
      // 11:45 UTC am 14.01.2026 ist in Berlin 12:45 (MEZ, +1) — nicht
      // 13:45, was der Sommerversatz ergäbe.
      final formular = BuchungsFormular.neu(
        vorlage: hafer,
        tagesSchluessel: '2026-01-14',
        jetzt: DateTime.utc(2026, 1, 14, 11, 45),
      );

      expect(formular.mahlzeit, Mahlzeit.mittag);
      expect(formular.minutenSeitMitternacht, 12 * 60 + 45);
      expect(formular.zeitpunkt, DateTime.utc(2026, 1, 14, 11, 45));
    });

    test('heute morgens: die Uhrzeit ist „jetzt", nicht die '
        'Frühstücksmitte', () {
      // 05:10 UTC ist 07:10 Berliner Zeit — Frühstück, und 07:10 statt
      // 08:00.
      final formular = BuchungsFormular.neu(
        vorlage: hafer,
        tagesSchluessel: heute,
        jetzt: DateTime.utc(2026, 7, 14, 5, 10),
      );

      expect(formular.mahlzeit, Mahlzeit.fruehstueck);
      expect(formular.minutenSeitMitternacht, 7 * 60 + 10);
      expect(
        formular.minutenSeitMitternacht,
        isNot(Mahlzeitfenster.mitteInMinuten(Mahlzeit.fruehstueck)),
      );
    });

    test('die Sekunden werden abgeschnitten, nicht gerundet', () {
      // 12:17:59,999 Berliner Zeit ist 12:17 — nicht 12:18.
      final formular = BuchungsFormular.neu(
        vorlage: hafer,
        tagesSchluessel: heute,
        jetzt: DateTime.utc(2026, 7, 14, 10, 17, 59, 999),
      );

      expect(formular.minutenSeitMitternacht, 12 * 60 + 17);
      expect(formular.zeitpunkt, DateTime.utc(2026, 7, 14, 10, 17));
    });

    test('ein geblätterter Tag bekommt ebenfalls „jetzt" — auf den offenen '
        'Tag', () {
      // „Jetzt" ist 12:05 am 14.07., offen ist der Montag, 13.07. Die
      // Mahlzeit kommt aus „jetzt" (Mittag), die Uhrzeit auch — nicht die
      // Mittagsmitte 12:30.
      final formular = BuchungsFormular.neu(
        vorlage: hafer,
        tagesSchluessel: montag,
        jetzt: DateTime.utc(2026, 7, 14, 10, 5),
      );

      expect(formular.mahlzeit, Mahlzeit.mittag);
      expect(formular.minutenSeitMitternacht, 12 * 60 + 5);
      // 12:05 Berliner Zeit am **13.07.** = 10:05 UTC am 13.07.
      expect(formular.zeitpunkt, DateTime.utc(2026, 7, 13, 10, 5));
    });

    test('auch ein Tag **nach** „jetzt" bekommt „jetzt"', () {
      // Geblättert ist geblättert, in beide Richtungen.
      final formular = BuchungsFormular.neu(
        vorlage: hafer,
        tagesSchluessel: '2026-07-15',
        jetzt: DateTime.utc(2026, 7, 14, 10, 5),
      );

      expect(formular.minutenSeitMitternacht, 12 * 60 + 5);
      // 12:05 Berliner Zeit am 15.07. = 10:05 UTC am 15.07.
      expect(formular.zeitpunkt, DateTime.utc(2026, 7, 15, 10, 5));
    });

    test('01:30 nach Mitternacht, offen ist der Kalendertag von „jetzt": '
        'es steht 01:30 da — der Zeitpunkt fällt auf den Folgetag (V14)', () {
      // 23:30 UTC am 13.07. ist in Berlin der 14.07., 01:30 — Abend.
      final formular = BuchungsFormular.neu(
        vorlage: hafer,
        tagesSchluessel: heute,
        jetzt: DateTime.utc(2026, 7, 13, 23, 30),
      );

      expect(formular.mahlzeit, Mahlzeit.abend);
      expect(formular.minutenSeitMitternacht, 1 * 60 + 30);
      // V14, normal: vor 04:00 der Folgetag. 01:30 Berliner Zeit auf dem
      // 14.07. ist der **15.07.** 01:30 = 23:30 UTC am 14.07. (#456)
      expect(formular.zeitpunkt, DateTime.utc(2026, 7, 14, 23, 30));
    });

    test('01:30 nach Mitternacht, offen ist der Vortag: es steht ebenfalls '
        '01:30 da — auf dem Vortag, mit dem Zeitpunkt „jetzt" (#373)', () {
      final jetzt = DateTime.utc(2026, 7, 13, 23, 30);
      final formular = BuchungsFormular.neu(
        vorlage: hafer,
        tagesSchluessel: montag,
        jetzt: jetzt,
      );

      expect(formular.mahlzeit, Mahlzeit.abend);
      expect(formular.minutenSeitMitternacht, 1 * 60 + 30);
      expect(formular.alsEintrag().tagesSchluessel, montag);
      // V14, normal: 01:30 auf dem Montag (13.07.) ist der 14.07., 01:30 —
      // also genau „jetzt", nicht 01:30 am 13.07. vor Beginn des Tages
      // (#373, #456).
      expect(formular.zeitpunkt, jetzt);
    });

    test('die Uhrzeit ist die Berliner, nicht die UTC-Uhrzeit', () {
      // 22:30 UTC am 14.07. ist in Berlin der 15.07., 00:30 — im Blatt
      // steht 00:30, nicht 22:30, gleich welcher Tag offen ist.
      final vierzehnter = BuchungsFormular.neu(
        vorlage: hafer,
        tagesSchluessel: heute,
        jetzt: DateTime.utc(2026, 7, 14, 22, 30),
      );
      expect(vierzehnter.mahlzeit, Mahlzeit.abend);
      expect(vierzehnter.minutenSeitMitternacht, 30);
      // V14, normal: 00:30 auf dem 14.07. ist der 15.07., 00:30 Berliner
      // Zeit = 22:30 UTC am 14.07. Mit der UTC-Uhrzeit stünde hier 22:30
      // Berliner Zeit am 14.07. = 20:30 UTC (#456).
      expect(vierzehnter.zeitpunkt, DateTime.utc(2026, 7, 14, 22, 30));

      final fuenfzehnter = BuchungsFormular.neu(
        vorlage: hafer,
        tagesSchluessel: '2026-07-15',
        jetzt: DateTime.utc(2026, 7, 14, 22, 30),
      );
      expect(fuenfzehnter.mahlzeit, Mahlzeit.abend);
      expect(fuenfzehnter.minutenSeitMitternacht, 30);
      // 00:30 auf dem 15.07. ist der 16.07., 00:30 Berliner Zeit = 22:30
      // UTC am 15.07. (V14, #456).
      expect(fuenfzehnter.zeitpunkt, DateTime.utc(2026, 7, 15, 22, 30));
    });

    test('mitMahlzeit zieht auch heute auf die Mitte der neuen Mahlzeit', () {
      final formular = BuchungsFormular.neu(
        vorlage: hafer,
        tagesSchluessel: heute,
        jetzt: DateTime.utc(2026, 7, 14, 10, 5), // 12:05, Mittag
      ).mitMahlzeit(Mahlzeit.abend);

      expect(formular.mahlzeit, Mahlzeit.abend);
      expect(formular.minutenSeitMitternacht, 19 * 60);
      expect(formular.zeitpunkt, DateTime.utc(2026, 7, 14, 17));
    });

    test('mitUhrzeit setzt auch heute genau die gewählte Uhrzeit', () {
      final formular = BuchungsFormular.neu(
        vorlage: hafer,
        tagesSchluessel: heute,
        jetzt: DateTime.utc(2026, 7, 14, 10, 5),
      ).mitUhrzeit(13 * 60 + 40);

      expect(formular.mahlzeit, Mahlzeit.mittag);
      expect(formular.minutenSeitMitternacht, 13 * 60 + 40);
      expect(formular.zeitpunkt, DateTime.utc(2026, 7, 14, 11, 40));
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Gebucht wird auf den offenen Tag, nicht auf heute', () {
    test('der Tagesschlüssel ist der übergebene, auch wenn heute ein '
        'anderer ist', () {
      final formular = BuchungsFormular.neu(
        vorlage: hafer,
        tagesSchluessel: montag,
        jetzt: mittags,
      );

      expect(formular.tagesSchluessel, montag);
      expect(formular.alsEintrag().tagesSchluessel, montag);
    });

    test('auf einem geblätterten Tag ist die Uhrzeit „jetzt", nicht die '
        'Mitte der Mahlzeit', () {
      // „Jetzt" ist 12:00 Berliner Zeit am 14.07., offen ist der Montag.
      // Im Formular steht 12:00, nicht die Mittagsmitte 12:30 (#328, Tims
      // Entscheidung vom 04.11.2026).
      final formular = BuchungsFormular.neu(
        vorlage: hafer,
        tagesSchluessel: montag,
        jetzt: mittags,
      );

      expect(formular.minutenSeitMitternacht, 12 * 60);
      expect(
        formular.minutenSeitMitternacht,
        isNot(Mahlzeitfenster.mitteInMinuten(Mahlzeit.mittag)),
      );
    });

    test('alle vier Mitten liegen in ihrem eigenen Fenster', () {
      for (final mahlzeit in Mahlzeit.values) {
        final formular = BuchungsFormular.neu(
          vorlage: hafer,
          tagesSchluessel: heute,
          jetzt: mittags,
        ).mitMahlzeit(mahlzeit);

        expect(
          Mahlzeitfenster.fuer(formular.minutenSeitMitternacht),
          mahlzeit,
          reason: '$mahlzeit',
        );
      }
    });

    test('der Zeitpunkt ist die Berliner Wanduhrzeit des offenen Tages als '
        'UTC — im Sommer', () {
      final formular = BuchungsFormular.neu(
        vorlage: hafer,
        tagesSchluessel: heute,
        jetzt: mittags,
      ).mitMahlzeit(Mahlzeit.abend);

      // 19:00 Berliner Zeit am 14.07.2026 (MESZ, +2) = 17:00 UTC.
      expect(formular.zeitpunkt, DateTime.utc(2026, 7, 14, 17));
      expect(formular.zeitpunkt.isUtc, isTrue);
    });

    test('… und im Winter mit dem anderen Versatz', () {
      final formular = BuchungsFormular.neu(
        vorlage: hafer,
        tagesSchluessel: '2026-01-14',
        jetzt: DateTime.utc(2026, 1, 14, 11),
      ).mitMahlzeit(Mahlzeit.abend);

      // 19:00 Berliner Zeit am 14.01.2026 (MEZ, +1) = 18:00 UTC.
      expect(formular.zeitpunkt, DateTime.utc(2026, 1, 14, 18));
    });

    test('der Zeitpunkt fällt auf den offenen Tag zurück, nicht auf den '
        'Tag von „jetzt"', () {
      final formular = BuchungsFormular.neu(
        vorlage: hafer,
        tagesSchluessel: montag,
        jetzt: mittags,
      ).mitMahlzeit(Mahlzeit.fruehstueck);

      // 08:00 Berliner Zeit am **13.07.** = 06:00 UTC am 13.07.
      expect(formular.zeitpunkt, DateTime.utc(2026, 7, 13, 6));
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Die Menge in Gramm und was daraus folgt', () {
    BuchungsFormular blatt() => BuchungsFormular.neu(
      vorlage: hafer,
      tagesSchluessel: heute,
      jetzt: mittags,
    );

    test(
      'die Vorgabemenge ist 100 g — dann stehen die eingegebenen Zahlen da',
      () {
        final formular = blatt();

        expect(formular.mengeG, 100);
        expect(formular.naehrwerte.kcal, closeTo(372, 1e-9));
      },
    );

    test('250 g von 372 kcal je 100 g ergeben 930 kcal', () {
      final formular = blatt().mitMenge('250');

      expect(formular.mengeG, 250);
      expect(formular.naehrwerte.kcal, closeTo(930, 1e-9));
    });

    test('jedes angegebene Feld skaliert mit', () {
      final werte = blatt().mitMenge('250').naehrwerte;

      expect(werte.eiweissG, closeTo(33.75, 1e-9));
      expect(werte.kohlenhydrateG, closeTo(146.75, 1e-9));
      expect(werte.fettG, closeTo(17.5, 1e-9));
      expect(werte.ballaststoffeG, closeTo(25, 1e-9));
    });

    test('ein fehlendes Feld bleibt nach der Rechnung fehlend, nicht 0', () {
      final werte = blatt().mitMenge('250').naehrwerte;

      expect(werte.zuckerG, isNull);
      expect(werte.gesaettigtG, isNull);
      expect(werte.wasserMl, isNull);
    });

    test('Komma und Punkt in der Menge ergeben dasselbe', () {
      expect(blatt().mitMenge('33,5').mengeG, 33.5);
      expect(blatt().mitMenge('33.5').mengeG, 33.5);
    });

    test('kannBuchen ist falsch ohne Menge, bei Unsinn und bei 0', () {
      expect(blatt().kannBuchen, isTrue);
      expect(blatt().mitMenge('').kannBuchen, isFalse);
      expect(blatt().mitMenge('eine Handvoll').kannBuchen, isFalse);
      expect(blatt().mitMenge('0').kannBuchen, isFalse);
      expect(blatt().mitMenge('-50').kannBuchen, isFalse);
    });

    test('ohne lesbare Menge gibt es keine Nährwerte — und keine Nullen', () {
      final werte = blatt().mitMenge('').naehrwerte;

      expect(blatt().mitMenge('').mengeG, isNull);
      expect(werte.kcal, isNull);
      expect(werte.eiweissG, isNull);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Was „Buchen" schreibt', () {
    test(
      'trägt Tag, Mahlzeit, Zeitpunkt, Vorlage, Menge und die Nährwerte',
      () {
        final eintrag = BuchungsFormular.neu(
          vorlage: hafer,
          tagesSchluessel: montag,
          jetzt: mittags,
        ).mitMenge('250').alsEintrag();

        expect(eintrag.id, isNull); // neu, noch nicht gebucht
        expect(eintrag.tagesSchluessel, montag);
        expect(eintrag.mahlzeit, Mahlzeit.mittag);
        // 12:00 Berliner Zeit — „jetzt" — auf dem Montag (#328).
        expect(eintrag.zeitpunkt, DateTime.utc(2026, 7, 13, 10));
        expect(eintrag.lebensmittelId, 42);
        expect(eintrag.name, 'Haferflocken kernig');
        expect(eintrag.mengeG, 250);
        expect(eintrag.naehrwerte.kcal, closeTo(930, 1e-9));
      },
    );

    test('ein frisch gebuchter Eintrag steht auf offen', () {
      // Gebucht wird immer, auch ohne Schreibfreigabe; `offen` heißt
      // „noch nicht nach Health geschrieben", nicht „nicht gespeichert".
      final eintrag = BuchungsFormular.neu(
        vorlage: hafer,
        tagesSchluessel: heute,
        jetzt: mittags,
      ).alsEintrag();

      expect(eintrag.healthStand, HealthStand.offen);
      expect(eintrag.healthUuid, isNull);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Ändern — dasselbe Blatt, vorbelegt', () {
    /// Ein gebuchter Eintrag: 250 g Haferflocken, Abendessen am Montag.
    final gebucht = Eintrag(
      id: 7,
      tagesSchluessel: montag,
      mahlzeit: Mahlzeit.abend,
      zeitpunkt: DateTime.utc(2026, 7, 13, 17), // 19:00 Berliner Zeit
      lebensmittelId: 42,
      name: 'Haferflocken kernig',
      mengeG: 250,
      naehrwerte: haferflocken.fuerMenge(250),
    );

    test('Menge, Mahlzeit, Uhrzeit und Tag stehen vorbelegt da', () {
      final formular = BuchungsFormular.fuer(gebucht);

      expect(formular.mengeG, 250);
      expect(formular.mahlzeit, Mahlzeit.abend);
      expect(formular.minutenSeitMitternacht, 19 * 60);
      expect(formular.tagesSchluessel, montag);
      expect(formular.name, 'Haferflocken kernig');
      expect(formular.lebensmittelId, 42);
    });

    test('das Blatt weiß, dass es ändert und nicht neu bucht', () {
      final formular = BuchungsFormular.fuer(gebucht);

      expect(formular.bearbeitetId, 7);
      expect(formular.alsEintrag().id, 7);
    });

    test('ein neues Blatt weiß das Gegenteil', () {
      final formular = BuchungsFormular.neu(
        vorlage: hafer,
        tagesSchluessel: heute,
        jetzt: mittags,
      );

      expect(formular.bearbeitetId, isNull);
    });

    test('unverändert gesichert kommt derselbe Eintrag wieder heraus', () {
      final wieder = BuchungsFormular.fuer(gebucht).alsEintrag();

      expect(wieder.tagesSchluessel, gebucht.tagesSchluessel);
      expect(wieder.mahlzeit, gebucht.mahlzeit);
      expect(wieder.zeitpunkt, gebucht.zeitpunkt);
      expect(wieder.mengeG, 250);
      expect(wieder.naehrwerte.kcal, closeTo(930, 1e-9));
    });

    test('die Menge zu ändern rechnet aus den **eingefrorenen** Werten des '
        'Eintrags', () {
      // Der entscheidende Fall: `BuchungsFormular.fuer` kennt die Vorlage
      // **nicht**. Es rechnet aus dem, was der Eintrag selbst trägt —
      // sonst zöge jede Mengenkorrektur stillschweigend die heutigen
      // Zahlen des Lebensmittels herein, und der Januar sähe nach jeder
      // Korrektur anders aus als damals.
      final geaendert = BuchungsFormular.fuer(gebucht).mitMenge('300');

      expect(geaendert.naehrwerte.kcal, closeTo(1116, 1e-6));
      expect(geaendert.naehrwerte.eiweissG, closeTo(40.5, 1e-6));
      expect(geaendert.naehrwerte.zuckerG, isNull);
    });

    test('die Mahlzeit umzuhängen zieht auch hier die Uhrzeit mit', () {
      final geaendert = BuchungsFormular.fuer(gebucht)
          .mitMahlzeit(Mahlzeit.fruehstueck);

      expect(geaendert.mahlzeit, Mahlzeit.fruehstueck);
      expect(geaendert.minutenSeitMitternacht, 8 * 60);
      // Und der Tag bleibt der Montag — umhängen ist nicht verschieben.
      expect(geaendert.alsEintrag().tagesSchluessel, montag);
      expect(geaendert.alsEintrag().zeitpunkt, DateTime.utc(2026, 7, 13, 6));
    });

    test('der Health-Stand des geänderten Eintrags bleibt, wie er war', () {
      // Was mit der Kopie in Apple Health geschieht, entscheidet der
      // Nachlauf — nicht das Blatt. Hier nur: Das Blatt erfindet keinen
      // Stand und wirft keine UUID weg.
      final drueben = Eintrag(
        id: 7,
        tagesSchluessel: montag,
        mahlzeit: Mahlzeit.abend,
        zeitpunkt: DateTime.utc(2026, 7, 13, 17),
        lebensmittelId: 42,
        name: 'Haferflocken kernig',
        mengeG: 250,
        naehrwerte: haferflocken.fuerMenge(250),
        healthUuid: 'FAKE-UUID-0001',
        healthStand: HealthStand.geschrieben,
      );

      final wieder = BuchungsFormular.fuer(drueben).alsEintrag();

      expect(wieder.healthUuid, 'FAKE-UUID-0001');
      expect(wieder.healthStand, HealthStand.geschrieben);
    });
  });
}
