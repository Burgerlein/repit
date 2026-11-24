import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für **`Umfang`** und **`UmfangsGruppe`** (#88, Task 1.1) — die
/// fünfzehn Maße aus `docs/SPEC.md` 4.6 mit ihrem stabilen Schlüssel, ihrem
/// deutschen Namen, ihrem Gegenstück, ihrem Messhinweis, ihrer Gruppe und
/// der Angabe, ob sie zu den vier wichtigsten gehören.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, nie verändert werden — sie legt fest, was
/// `Packages/trainings_core/lib/src/umfang.dart` zu leisten hat.
///
/// ## Woher die Festlegungen kommen
///
/// - **Fünfzehn Maße, nicht dreizehn.** `docs/SPEC.md` 4.6 und
///   `docs/superpowers/plans/2026-11-11-umfaenge.md`: Der Entwurf führte
///   Unterarm rechts/links und ließ Oberarm locker weg, die Spec umgekehrt.
///   Tim hat am 11.11.2026 beides zusammengelegt.
/// - **Die Swift-Vorlage** ist
///   `Packages/TrainingsCore/Sources/TrainingsCore/Body/Circumference.swift`
///   samt `CircumferencePartnerTests.swift`. Sie kennt dreizehn Maße; die
///   beiden Unterarme sind hier neu, Messhinweis und Gegenstück für sie
///   ebenso.
/// - **Die deutschen Namen gehören in den Kern** (`CLAUDE.md`, „Eine
///   Ausnahme", und die Global Constraints des Plans): Maß, Messstelle und
///   Richtung gehören zusammen, genau wie beim Übungskatalog.
///   **Abschnitts- und Knopfbeschriftungen nicht** — deshalb prüft diese
///   Datei an `UmfangsGruppe` *keinen* deutschen Text. „Arme", „Rumpf" und
///   „Beine" sind Kartenüberschriften des Formulars und gehören in die View.
///
/// ## Festgelegte öffentliche API
///
/// Neu in `Packages/trainings_core/lib/src/umfang.dart`, exportiert über
/// `lib/trainings_core.dart`:
///
/// ```dart
/// /// Die drei Karten des Formulars — zugleich die Reihenfolge, in der
/// /// `Umfang.values` läuft.
/// enum UmfangsGruppe { arme, rumpf, beine }
///
/// enum Umfang {
///   oberarmRechtsLocker('upperArmRightRelaxed'),
///   …;
///
///   const Umfang(this.schluessel);
///
///   /// Der stabile Schlüssel in Datenbank und Importdatei.
///   final String schluessel;
///
///   String get deutsch;
///   bool get wenigerIstBesser;
///   Umfang? get partner;
///   String get messhinweis;
///   UmfangsGruppe get gruppe;
///   bool get istWichtig;
///
///   /// Das Maß zu einem abgelegten Schlüssel, oder `null`, wenn der
///   /// Schlüssel zu keinem gehört.
///   static Umfang? vonSchluessel(String schluessel);
/// }
/// ```
///
/// **`vonSchluessel` ist Pflicht und nicht Beiwerk.** Die Ablage schreibt
/// `Umfang.schluessel` in die Spalte `mass`; ohne den Weg zurück ließe sich
/// keine Zeile lesen. Ein unbekannter Schlüssel ergibt `null` und keine
/// Ausnahme: Eine fremde Importdatei darf das Lesen nicht abbrechen.
///
/// ## Erfundene Zahlen
///
/// In dieser Datei steht kein einziger Messwert — hier geht es um die Maße
/// selbst. Echte Gesundheitswerte stünden ohnehin nie im Quelltext
/// (`CLAUDE.md`).
void main() {
  /// Die Reihenfolge des Formulars: Arme (6), Rumpf (5), Beine (4). Beim
  /// Messen arbeitet man mit dem Maßband den Körper hinunter.
  const reihenfolgeDesFormulars = <Umfang>[
    Umfang.oberarmRechtsLocker,
    Umfang.oberarmRechtsAngespannt,
    Umfang.oberarmLinksLocker,
    Umfang.oberarmLinksAngespannt,
    Umfang.unterarmRechts,
    Umfang.unterarmLinks,
    Umfang.brust,
    Umfang.schultern,
    Umfang.taille,
    Umfang.hals,
    Umfang.huefte,
    Umfang.oberschenkelRechts,
    Umfang.oberschenkelLinks,
    Umfang.wadeRechts,
    Umfang.wadeLinks,
  ];

  group('Es sind fünfzehn Maße', () {
    test('genau fünfzehn, nicht dreizehn', () {
      expect(
        Umfang.values.length,
        15,
        reason:
            'SPEC 4.6 seit dem 11.11.2026: Oberarm locker **und** Unterarm, '
            'nicht eins von beidem',
      );
    });

    test('`values` läuft in der Reihenfolge des Formulars', () {
      // `values` ist die Reihenfolge, in der das Formular die Felder
      // zeigt und in der die Tabelle sie führt. Eine Gruppe, die zweimal
      // auftaucht, zerrisse eine der drei Karten.
      expect(Umfang.values, reihenfolgeDesFormulars);
    });

    test('kein Maß steht doppelt', () {
      expect(Umfang.values.toSet().length, 15);
    });
  });

  group('Die Schlüssel sind das, was in der Datenbank steht', () {
    test('alle fünfzehn, in der Reihenfolge der Maße', () {
      expect(Umfang.values.map((mass) => mass.schluessel).toList(), [
        'upperArmRightRelaxed',
        'upperArmRightFlexed',
        'upperArmLeftRelaxed',
        'upperArmLeftFlexed',
        'forearmRight',
        'forearmLeft',
        'chest',
        'shoulders',
        'waist',
        'neck',
        'hips',
        'thigh',
        'thighLeft',
        'calf',
        'calfLeft',
      ]);
    });

    // Der wichtigste Testfall dieser Datei. Tims abgelegte und exportierte
    // Dateien kennen für Oberschenkel und Wade **nur** `thigh` und `calf`.
    // Wanderten die beiden Rohwerte nach links, läsen sich alte Messungen
    // als die falsche Seite — und das sähe niemand, weil beide Zahlen
    // plausibel sind. Der Unterschied ist „Oberschenkel rechts seit August
    // +0,7" gegen eine Zahl, die niemandem gehört.
    test('`thigh` und `calf` gehören zu den rechten Maßen', () {
      expect(Umfang.oberschenkelRechts.schluessel, 'thigh');
      expect(Umfang.wadeRechts.schluessel, 'calf');
      expect(Umfang.oberschenkelLinks.schluessel, 'thighLeft');
      expect(Umfang.wadeLinks.schluessel, 'calfLeft');
    });

    test('`thigh` und `calf` werden auch als rechts zurückgelesen', () {
      expect(Umfang.vonSchluessel('thigh'), Umfang.oberschenkelRechts);
      expect(Umfang.vonSchluessel('calf'), Umfang.wadeRechts);
    });

    test('jeder Schlüssel findet sein Maß wieder', () {
      for (final mass in Umfang.values) {
        expect(
          Umfang.vonSchluessel(mass.schluessel),
          mass,
          reason: 'Hin und zurück muss dasselbe Maß ergeben: ${mass.deutsch}',
        );
      }
    });

    test('ein unbekannter Schlüssel ergibt null und keine Ausnahme', () {
      // Eine fremde oder ältere Importdatei darf das Lesen nicht
      // abbrechen; die Zeile fällt weg, der Rest kommt an.
      expect(Umfang.vonSchluessel('bauchumfang'), isNull);
      expect(Umfang.vonSchluessel(''), isNull);
      // Nicht der Dart-Name, sondern der Schlüssel entscheidet.
      expect(Umfang.vonSchluessel('oberschenkelRechts'), isNull);
    });

    test('kein Schlüssel steht doppelt', () {
      expect(Umfang.values.map((mass) => mass.schluessel).toSet().length, 15);
    });
  });

  group('Die deutschen Namen', () {
    test('jedes Maß trägt seinen Namen aus SPEC 4.6', () {
      expect(Umfang.oberarmRechtsLocker.deutsch, 'Oberarm rechts, locker');
      expect(
        Umfang.oberarmRechtsAngespannt.deutsch,
        'Oberarm rechts, angespannt',
      );
      expect(Umfang.oberarmLinksLocker.deutsch, 'Oberarm links, locker');
      expect(
        Umfang.oberarmLinksAngespannt.deutsch,
        'Oberarm links, angespannt',
      );
      expect(Umfang.unterarmRechts.deutsch, 'Unterarm rechts');
      expect(Umfang.unterarmLinks.deutsch, 'Unterarm links');
      expect(Umfang.brust.deutsch, 'Brust');
      expect(Umfang.schultern.deutsch, 'Schultern');
      // Die Messstelle gehört zum Namen: Eine Taille lässt sich an drei
      // Stellen messen, und drei Stellen ergäben drei Verläufe.
      expect(Umfang.taille.deutsch, 'Taille (Nabel)');
      expect(Umfang.hals.deutsch, 'Hals');
      expect(Umfang.huefte.deutsch, 'Hüfte');
      expect(Umfang.oberschenkelRechts.deutsch, 'Oberschenkel rechts');
      expect(Umfang.oberschenkelLinks.deutsch, 'Oberschenkel links');
      expect(Umfang.wadeRechts.deutsch, 'Wade rechts');
      expect(Umfang.wadeLinks.deutsch, 'Wade links');
    });

    test('keine zwei Maße heißen gleich', () {
      // Zwei gleiche Beschriftungen wären in der Liste nicht
      // auseinanderzuhalten — etwa links und rechts, die nur im Schlüssel
      // abweichen.
      expect(Umfang.values.map((mass) => mass.deutsch).toSet().length, 15);
    });
  });

  group('Weniger ist besser — nur bei der Taille', () {
    test('die Taille ist das einzige Maß, das schrumpfen soll', () {
      // Das Ziel heißt „Oberarm und Brust wachsen, Taille bleibt". Die
      // Regel steckt im Maß und nicht in der Farbe der Ansicht.
      expect(Umfang.values.where((mass) => mass.wenigerIstBesser).toList(), [
        Umfang.taille,
      ]);
    });

    test('die Hüfte gehört ausdrücklich nicht dazu', () {
      // Naheliegend, aber falsch: Die Hüfte misst mit, was am Gesäß
      // aufgebaut wird.
      expect(Umfang.huefte.wenigerIstBesser, isFalse);
    });
  });

  group('Das Gegenstück ist die andere Seite', () {
    // Auslegung, wie in `CircumferencePartnerTests.swift` begründet: Das
    // Gegenstück ist dieselbe Messart auf der **anderen Seite**. Locker und
    // angespannt desselben Arms sind kein Paar — gemeint ist die
    // Seitendifferenz, nicht der Anspannungszuwachs.
    test('locker rechts und locker links gehören zusammen', () {
      expect(Umfang.oberarmRechtsLocker.partner, Umfang.oberarmLinksLocker);
      expect(Umfang.oberarmLinksLocker.partner, Umfang.oberarmRechtsLocker);
    });

    test('angespannt rechts und angespannt links gehören zusammen', () {
      expect(
        Umfang.oberarmRechtsAngespannt.partner,
        Umfang.oberarmLinksAngespannt,
      );
      expect(
        Umfang.oberarmLinksAngespannt.partner,
        Umfang.oberarmRechtsAngespannt,
      );
    });

    test('die beiden Unterarme gehören zusammen', () {
      // Neu gegenüber der Swift-Fassung, dort gibt es den Unterarm nicht.
      expect(Umfang.unterarmRechts.partner, Umfang.unterarmLinks);
      expect(Umfang.unterarmLinks.partner, Umfang.unterarmRechts);
    });

    test('die beiden Oberschenkel gehören zusammen', () {
      expect(Umfang.oberschenkelRechts.partner, Umfang.oberschenkelLinks);
      expect(Umfang.oberschenkelLinks.partner, Umfang.oberschenkelRechts);
    });

    test('die beiden Waden gehören zusammen', () {
      expect(Umfang.wadeRechts.partner, Umfang.wadeLinks);
      expect(Umfang.wadeLinks.partner, Umfang.wadeRechts);
    });

    test('locker und angespannt desselben Arms sind kein Paar', () {
      expect(
        Umfang.oberarmRechtsLocker.partner,
        isNot(Umfang.oberarmRechtsAngespannt),
      );
      expect(
        Umfang.oberarmRechtsAngespannt.partner,
        isNot(Umfang.oberarmRechtsLocker),
      );
      expect(
        Umfang.oberarmLinksLocker.partner,
        isNot(Umfang.oberarmLinksAngespannt),
      );
      expect(
        Umfang.oberarmLinksAngespannt.partner,
        isNot(Umfang.oberarmLinksLocker),
      );
    });

    test('Brust, Schultern, Taille, Hals und Hüfte haben kein Gegenstück', () {
      for (final mass in [
        Umfang.brust,
        Umfang.schultern,
        Umfang.taille,
        Umfang.hals,
        Umfang.huefte,
      ]) {
        expect(
          mass.partner,
          isNull,
          reason: '${mass.deutsch} gibt es nur einmal am Körper',
        );
      }
    });

    test('zehn Maße haben ein Gegenstück, fünf nicht', () {
      final gepaart = Umfang.values
          .where((mass) => mass.partner != null)
          .toList();
      expect(gepaart.length, 10);
      expect(Umfang.values.length - gepaart.length, 5);
    });

    test('kein Maß ist sein eigenes Gegenstück', () {
      for (final mass in Umfang.values) {
        expect(
          mass.partner,
          isNot(mass),
          reason: '${mass.deutsch} zeigt auf sich selbst',
        );
      }
    });

    test('die Beziehung ist symmetrisch', () {
      // Sonst zeichnete der Verlauf des einen Maßes eine zweite Linie, der
      // des anderen aber nicht — derselbe Vergleich hinge davon ab, von
      // welcher Seite man ihn aufruft.
      for (final mass in Umfang.values) {
        final partner = mass.partner;
        if (partner == null) continue;
        expect(
          partner.partner,
          mass,
          reason:
              '${mass.deutsch} und ${partner.deutsch} zeigen nicht '
              'aufeinander',
        );
      }
    });

    test('ein Gegenstück steht in derselben Gruppe', () {
      // Arme mit Armen, Beine mit Beinen: Ein Paar über zwei Karten hinweg
      // wäre im Formular wie im Diagramm ein Fehler.
      for (final mass in Umfang.values) {
        final partner = mass.partner;
        if (partner == null) continue;
        expect(partner.gruppe, mass.gruppe);
      }
    });
  });

  group('Je Maß ein eigener Messhinweis', () {
    test('jedes Maß hat einen', () {
      for (final mass in Umfang.values) {
        expect(
          mass.messhinweis.trim(),
          isNotEmpty,
          reason: '${mass.deutsch} hat keinen Messhinweis',
        );
      }
    });

    test('es ist jeweils ein Satz und kein Platzhalter', () {
      // „Dickste Stelle, Arm entspannt" sagt, wo das Maßband liegt. Ein
      // Wort tut das nicht, und ein leer gelassener Hinweis fiele erst im
      // Verlauf auf, wenn die Zahlen schon streuen.
      for (final mass in Umfang.values) {
        expect(
          mass.messhinweis.trim().length,
          greaterThan(20),
          reason: '${mass.deutsch}: „${mass.messhinweis}" ist kein Satz',
        );
      }
    });

    test('die fünfzehn Hinweise sind voneinander verschieden', () {
      // Ein Sammelsatz, fünfzehnmal wiederholt, hilft beim Messen nicht —
      // und rechts und links unterscheiden sich gerade darin, welches Bein
      // belastet ist.
      expect(Umfang.values.map((mass) => mass.messhinweis).toSet().length, 15);
    });
  });

  group('Die drei Gruppen des Formulars', () {
    test('arme, rumpf, beine — in dieser Reihenfolge', () {
      expect(UmfangsGruppe.values, [
        UmfangsGruppe.arme,
        UmfangsGruppe.rumpf,
        UmfangsGruppe.beine,
      ]);
    });

    test('Arme sechs, Rumpf fünf, Beine vier', () {
      int anzahl(UmfangsGruppe gruppe) =>
          Umfang.values.where((mass) => mass.gruppe == gruppe).length;
      // Sechs und nicht vier: Der Unterarm gehört zu den Armen.
      expect(anzahl(UmfangsGruppe.arme), 6);
      expect(anzahl(UmfangsGruppe.rumpf), 5);
      expect(anzahl(UmfangsGruppe.beine), 4);
    });

    test('jedes Maß steht in der Gruppe, in der man es misst', () {
      expect(Umfang.oberarmRechtsLocker.gruppe, UmfangsGruppe.arme);
      expect(Umfang.oberarmLinksAngespannt.gruppe, UmfangsGruppe.arme);
      expect(Umfang.unterarmRechts.gruppe, UmfangsGruppe.arme);
      expect(Umfang.unterarmLinks.gruppe, UmfangsGruppe.arme);
      expect(Umfang.brust.gruppe, UmfangsGruppe.rumpf);
      expect(Umfang.schultern.gruppe, UmfangsGruppe.rumpf);
      expect(Umfang.taille.gruppe, UmfangsGruppe.rumpf);
      expect(Umfang.hals.gruppe, UmfangsGruppe.rumpf);
      expect(Umfang.huefte.gruppe, UmfangsGruppe.rumpf);
      expect(Umfang.oberschenkelRechts.gruppe, UmfangsGruppe.beine);
      expect(Umfang.oberschenkelLinks.gruppe, UmfangsGruppe.beine);
      expect(Umfang.wadeRechts.gruppe, UmfangsGruppe.beine);
      expect(Umfang.wadeLinks.gruppe, UmfangsGruppe.beine);
    });

    test('die Maße einer Gruppe stehen beisammen', () {
      // `values` ist die Reihenfolge des Formulars. Eine Gruppe, die
      // zweimal auftaucht, zerrisse eine der drei Karten.
      final erwartet = <UmfangsGruppe>[
        ...List.filled(6, UmfangsGruppe.arme),
        ...List.filled(5, UmfangsGruppe.rumpf),
        ...List.filled(4, UmfangsGruppe.beine),
      ];
      expect(Umfang.values.map((mass) => mass.gruppe).toList(), erwartet);
    });
  });

  group('Die vier wichtigsten Maße', () {
    test('angespannte Oberarme, Brust und Taille — in der Reihenfolge der '
        'Übersicht', () {
      // Die Übersicht sortiert nach Wichtigkeit fürs Ziel, das Formular
      // nach Körperregion (Plan, „Zwei Schirme, zwei Reihenfolgen").
      // Gefiltert aus `values` ergibt sich genau die Reihenfolge, in der
      // `docs/screens/screens/umfaenge.js` die Gruppe „Für dein Ziel am
      // wichtigsten" zeigt.
      expect(Umfang.values.where((mass) => mass.istWichtig).toList(), [
        Umfang.oberarmRechtsAngespannt,
        Umfang.oberarmLinksAngespannt,
        Umfang.brust,
        Umfang.taille,
      ]);
    });

    test('es sind genau vier, die übrigen elf stehen in Grau', () {
      expect(Umfang.values.where((mass) => mass.istWichtig).length, 4);
      expect(Umfang.values.where((mass) => !mass.istWichtig).length, 11);
    });

    test('der locker gemessene Oberarm gehört nicht dazu', () {
      // Gewachsen ist der Arm, wenn er angespannt wächst; locker schwankt
      // mit Tagesform und Haltung.
      expect(Umfang.oberarmRechtsLocker.istWichtig, isFalse);
      expect(Umfang.oberarmLinksLocker.istWichtig, isFalse);
    });
  });
}
