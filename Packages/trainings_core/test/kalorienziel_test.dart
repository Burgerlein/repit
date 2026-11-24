import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für `Packages/trainings_core/lib/src/kalorienziel.dart` — Task 2 des
/// Umsetzungsplans `docs/superpowers/plans/2026-11-03-ernaehrung.md`, Spec
/// `docs/SPEC.md` 4.8 („Kalorienziel pro Tag") und 3.1 („Körperziel").
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf **ausgeführt, nie verändert** werden. Hält der
/// Implementierende eine Erwartung für falsch, wird das **gemeldet, nicht
/// korrigiert**.
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// ```dart
/// double? kalorienziel({
///   double? aktivKcal,
///   double? basalKcal,
///   double? gewichtKg,
///   int? groesseCm,
///   int? alter,
///   double? zielgewichtKg,
///   int? tageBisZiel,
///   double? trainingsaufschlagKcal,
///   bool inErholung = false,
///   double? gewichtstrendKgProWoche,
/// });
/// ```
///
/// ## Die Formel, Satz für Satz aus `docs/SPEC.md` 4.8
///
/// > Gibt es ganztägige Watch-Daten (Grundumsatz ≥ 1.400 kcal):
/// > Verbrauch = aktiv + Grundumsatz.
/// > Sonst: Grundbedarf = Mifflin-St Jeor (10·kg + 6,25·cm − 5·Alter + 5)
/// > · 1,4, plus Training […].
/// > Plus Überschuss aus dem Körperziel (3.1): nötige kg/Woche · 7.700
/// > kcal/kg ÷ 7, begrenzt auf 100 bis 400 kcal pro Tag. Weicht der
/// > gemessene 6-Wochen-Gewichtstrend von der nötigen Rate ab, korrigiert
/// > die App den Wert nach. In der OP-Erholung 0.
///
/// `7700 / 7` ist glatt `1100`; eine Rate von 0,20 kg/Woche sind also
/// 220 kcal am Tag.
///
/// ## Entscheidungen des Test-Agenten, wo die Spec Spielraum lässt
///
/// 1. **Ohne Körperziel gibt es keinen Überschuss — er ist `0`, nicht die
///    Untergrenze 100.** Der Deckel „100 bis 400" begrenzt eine *gerechnete*
///    Rate; wo keine Rate existiert, gibt es nichts zu begrenzen. Sonst
///    äße Tim 100 kcal am Tag zu viel, nur weil er kein Ziel eingetragen
///    hat.
/// 2. **Eine nicht-positive Rate ergibt `0`**, kein Defizit und keine
///    Anhebung auf 100. Wer ein Zielgewicht unter dem heutigen einträgt,
///    bekommt von dieser Formel keinen Aufschlag; ein Abnehmziel ist in
///    3.1 nicht beschrieben, und der Kern rät nicht.
/// 3. **`tageBisZiel <= 0` ergibt ebenfalls `0`.** Das Zieldatum ist
///    erreicht oder vorbei; eine Division durch null wäre `Infinity` und
///    liefe durch jeden Deckel.
/// 4. **Die Trendkorrektur ist die volle Lücke.** Nötige Rate 0,20, gemessen
///    0,10 → es fehlen 0,10, also wird mit 0,30 weitergerechnet
///    (`effektiv = noetig + (noetig − trend)`). Danach greift derselbe
///    Deckel 100…400. Die Spec sagt „korrigiert nach", nicht um wie viel;
///    die volle Lücke ist die einfachste Regel, die die Zielrate wirklich
///    wiederherstellt, und der Deckel fängt den Überschwung.
/// 5. **Der Trainingsaufschlag gilt nur im Mifflin-Weg.** Die Watch-Zahl
///    „aktiv" enthält das Training bereits; beides zu addieren zählte es
///    doppelt — genau der Fall, den die Spec mit „Watch-Workouts […] am
///    Gym-Tag nicht doppelt zählen" meint.
/// 6. **Der Watch-Weg braucht beide Zahlen.** `basalKcal ≥ 1400` allein
///    reicht nicht, wenn `aktivKcal` fehlt — „Verbrauch = aktiv +
///    Grundumsatz" ließe sich sonst nur mit einer erfundenen Null bilden.
/// 7. **Ohne Größe, Gewicht oder Alter gibt es kein Ziel — `null`.** Der
///    Plan nennt Gewicht und Größe; Alter steht hier daneben, weil
///    Mifflin-St Jeor es genauso braucht und ein geschätztes Alter eine
///    stille Falschauskunft wäre. Die Grenze ist zusätzlich `<= 0`, wie bei
///    `ProteinTarget.grams`. **`null` heißt „kein Ziel berechenbar", und der
///    Schirm führt dann auf die Einstellungen** — es heißt nicht `0`.
///
/// ## Alle Zahlen hier sind erfunden
///
/// 70,0 kg / 180 cm / 22 Jahre sind glatte Rechenwerte, nicht Tims Daten;
/// `docs/SPEC.md` 3.1 nennt andere. Mifflin ergibt damit
/// `10·70 + 6,25·180 − 5·22 + 5 = 1720`, mal 1,4 sind **2408 kcal**.
void main() {
  /// Vorbelegte Stammdaten, damit jeder Fall nur nennt, worum es ihm geht.
  double? ziel({
    double? aktivKcal,
    double? basalKcal,
    double? gewichtKg = 70,
    int? groesseCm = 180,
    int? alter = 22,
    double? zielgewichtKg,
    int? tageBisZiel,
    double? trainingsaufschlagKcal,
    bool inErholung = false,
    double? gewichtstrendKgProWoche,
  }) => kalorienziel(
    aktivKcal: aktivKcal,
    basalKcal: basalKcal,
    gewichtKg: gewichtKg,
    groesseCm: groesseCm,
    alter: alter,
    zielgewichtKg: zielgewichtKg,
    tageBisZiel: tageBisZiel,
    trainingsaufschlagKcal: trainingsaufschlagKcal,
    inErholung: inErholung,
    gewichtstrendKgProWoche: gewichtstrendKgProWoche,
  );

  group('ganztägige Watch-Daten', () {
    test('Grundumsatz 1500 plus aktiv 600 ergibt 2100', () {
      expect(ziel(basalKcal: 1500, aktivKcal: 600), closeTo(2100, 1e-6));
    });

    test('1.400 ist die Grenze und gehört noch zu den Watch-Daten', () {
      expect(ziel(basalKcal: 1400, aktivKcal: 500), closeTo(1900, 1e-6));
    });

    test('der Trainingsaufschlag wird nicht dazugezählt', () {
      expect(
        ziel(basalKcal: 1500, aktivKcal: 600, trainingsaufschlagKcal: 300),
        closeTo(2100, 1e-6),
        reason: 'aktiv enthält das Training schon',
      );
    });
  });

  group('Rückfall auf Mifflin-St Jeor', () {
    test('ein Grundumsatz unter 1.400 zählt nicht als ganztägig', () {
      expect(ziel(basalKcal: 900, aktivKcal: 600), closeTo(2408, 1e-6));
    });

    test('1.399 ist noch darunter', () {
      expect(ziel(basalKcal: 1399, aktivKcal: 600), closeTo(2408, 1e-6));
    });

    test('ein hoher Grundumsatz ohne aktiv reicht nicht', () {
      expect(ziel(basalKcal: 1500), closeTo(2408, 1e-6));
    });

    test('ganz ohne Watch-Daten', () {
      expect(ziel(), closeTo(2408, 1e-6));
    });

    test('der Trainingsaufschlag kommt hier obendrauf', () {
      expect(
        ziel(trainingsaufschlagKcal: 300),
        closeTo(2708, 1e-6),
      );
    });

    test('ein fehlender Trainingsaufschlag ist 0, nicht ein Fehler', () {
      expect(ziel(trainingsaufschlagKcal: null), closeTo(2408, 1e-6));
    });
  });

  group('ohne Stammdaten gibt es kein Ziel', () {
    test('ohne Gewicht', () {
      expect(ziel(gewichtKg: null, basalKcal: 1500, aktivKcal: 600), isNull);
    });

    test('ohne Größe', () {
      expect(ziel(groesseCm: null, basalKcal: 1500, aktivKcal: 600), isNull);
    });

    test('ohne Alter', () {
      expect(ziel(alter: null, basalKcal: 1500, aktivKcal: 600), isNull);
    });

    test('ein Gewicht oder eine Größe von 0 ist keine Angabe', () {
      expect(ziel(gewichtKg: 0), isNull);
      expect(ziel(groesseCm: 0), isNull);
    });

    test('mit allen dreien gibt es wieder eine Zahl', () {
      expect(ziel(), isNotNull);
    });
  });

  group('Überschuss aus dem Körperziel', () {
    test('0,20 kg/Woche sind 220 kcal am Tag', () {
      // 2 kg in 70 Tagen = 0,20 kg/Woche; 0,20 · 7700 / 7 = 220.
      expect(
        ziel(
          basalKcal: 1500,
          aktivKcal: 600,
          zielgewichtKg: 72,
          tageBisZiel: 70,
        ),
        closeTo(2320, 1e-6),
      );
    });

    test('er gilt auch auf dem Mifflin-Weg', () {
      expect(
        ziel(zielgewichtKg: 72, tageBisZiel: 70),
        closeTo(2628, 1e-6),
      );
    });

    test('nach oben bei 400 kcal gedeckelt', () {
      // 5 kg in 70 Tagen = 0,50 kg/Woche = 550 kcal → 400.
      expect(
        ziel(
          basalKcal: 1500,
          aktivKcal: 600,
          zielgewichtKg: 75,
          tageBisZiel: 70,
        ),
        closeTo(2500, 1e-6),
      );
    });

    test('nach unten bei 100 kcal angehoben', () {
      // 0,5 kg in 70 Tagen = 0,05 kg/Woche = 55 kcal → 100.
      expect(
        ziel(
          basalKcal: 1500,
          aktivKcal: 600,
          zielgewichtKg: 70.5,
          tageBisZiel: 70,
        ),
        closeTo(2200, 1e-6),
      );
    });

    test('ohne Körperziel gibt es keinen Überschuss — auch nicht 100', () {
      expect(ziel(basalKcal: 1500, aktivKcal: 600), closeTo(2100, 1e-6));
    });

    test('ein halbes Körperziel ist keines', () {
      expect(
        ziel(basalKcal: 1500, aktivKcal: 600, zielgewichtKg: 72),
        closeTo(2100, 1e-6),
        reason: 'ohne Zieldatum keine Rate',
      );
      expect(
        ziel(basalKcal: 1500, aktivKcal: 600, tageBisZiel: 70),
        closeTo(2100, 1e-6),
        reason: 'ohne Zielgewicht keine Rate',
      );
    });

    test('ein erreichtes oder vergangenes Zieldatum ergibt keinen Zuschlag', () {
      expect(
        ziel(
          basalKcal: 1500,
          aktivKcal: 600,
          zielgewichtKg: 72,
          tageBisZiel: 0,
        ),
        closeTo(2100, 1e-6),
      );
      expect(
        ziel(
          basalKcal: 1500,
          aktivKcal: 600,
          zielgewichtKg: 72,
          tageBisZiel: -14,
        ),
        closeTo(2100, 1e-6),
      );
    });

    test('ein Zielgewicht unter dem heutigen ergibt keinen Zuschlag', () {
      expect(
        ziel(
          basalKcal: 1500,
          aktivKcal: 600,
          zielgewichtKg: 68,
          tageBisZiel: 70,
        ),
        closeTo(2100, 1e-6),
      );
    });

    test('ein bereits erreichtes Zielgewicht ergibt keinen Zuschlag', () {
      expect(
        ziel(
          basalKcal: 1500,
          aktivKcal: 600,
          zielgewichtKg: 70,
          tageBisZiel: 70,
        ),
        closeTo(2100, 1e-6),
      );
    });

    test('in der Erholung ist der Überschuss 0', () {
      expect(
        ziel(
          basalKcal: 1500,
          aktivKcal: 600,
          zielgewichtKg: 72,
          tageBisZiel: 70,
          inErholung: true,
        ),
        closeTo(2100, 1e-6),
      );
    });

    test('die Erholung nimmt nur den Überschuss, nicht den Verbrauch', () {
      expect(
        ziel(basalKcal: 1500, aktivKcal: 600, inErholung: true),
        closeTo(2100, 1e-6),
      );
    });
  });

  group('Trendkorrektur', () {
    test('zu langsam zugenommen hebt den Überschuss', () {
      // nötig 0,20 — gemessen 0,10 — gerechnet wird mit 0,30 = 330 kcal.
      expect(
        ziel(
          basalKcal: 1500,
          aktivKcal: 600,
          zielgewichtKg: 72,
          tageBisZiel: 70,
          gewichtstrendKgProWoche: 0.10,
        ),
        closeTo(2430, 1e-6),
      );
    });

    test('zu schnell zugenommen senkt ihn', () {
      // nötig 0,20 — gemessen 0,30 — gerechnet wird mit 0,10 = 110 kcal.
      expect(
        ziel(
          basalKcal: 1500,
          aktivKcal: 600,
          zielgewichtKg: 72,
          tageBisZiel: 70,
          gewichtstrendKgProWoche: 0.30,
        ),
        closeTo(2210, 1e-6),
      );
    });

    test('weit über der nötigen Rate bleibt kein Überschuss', () {
      // nötig 0,20 — gemessen 0,50 — gerechnet wird mit −0,10 → 0 kcal.
      expect(
        ziel(
          basalKcal: 1500,
          aktivKcal: 600,
          zielgewichtKg: 72,
          tageBisZiel: 70,
          gewichtstrendKgProWoche: 0.50,
        ),
        closeTo(2100, 1e-6),
      );
    });

    test('ein Trend ohne Körperziel ändert nichts', () {
      expect(
        ziel(
          basalKcal: 1500,
          aktivKcal: 600,
          gewichtstrendKgProWoche: 0.10,
        ),
        closeTo(2100, 1e-6),
      );
    });

    test('in der Erholung wird auch nicht nachkorrigiert', () {
      expect(
        ziel(
          basalKcal: 1500,
          aktivKcal: 600,
          zielgewichtKg: 72,
          tageBisZiel: 70,
          gewichtstrendKgProWoche: 0.10,
          inErholung: true,
        ),
        closeTo(2100, 1e-6),
      );
    });

    test('ein fehlender Trend lässt die nötige Rate stehen', () {
      expect(
        ziel(
          basalKcal: 1500,
          aktivKcal: 600,
          zielgewichtKg: 72,
          tageBisZiel: 70,
          gewichtstrendKgProWoche: null,
        ),
        closeTo(2320, 1e-6),
      );
    });
  });
}
