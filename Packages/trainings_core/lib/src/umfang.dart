/// Die fünfzehn Körpermaße aus `docs/SPEC.md` 4.6 (#88, #475) — mit ihrem
/// stabilen Schlüssel, ihrem deutschen Namen, ihrem Gegenstück, ihrem
/// Messhinweis, ihrer Gruppe und der Angabe, ob sie zu den vier wichtigsten
/// gehören.
///
/// Verbindlich festgelegt durch `Packages/trainings_core/test/umfang_test.dart`
/// (siehe dessen Dateikopf) — diese Datei darf die Tests ausführen, aber nicht
/// verändern (`CLAUDE.md`, „Wer Tests schreibt, schreibt nicht die
/// Implementierung").
///
/// Die deutschen Namen und die Messhinweise stehen hier und nicht in der
/// Ansicht: Maß, Messstelle und Richtung gehören zusammen, genau wie beim
/// Übungskatalog (`CLAUDE.md`, „Eine Ausnahme"). Karten- und
/// Knopfbeschriftungen gehören dagegen in die View — deshalb trägt
/// [UmfangsGruppe] hier keinen deutschen Text.
///
/// Dart-Gegenstück zu
/// `Packages/TrainingsCore/Sources/TrainingsCore/Body/Circumference.swift`.
/// Jene Fassung kennt dreizehn Maße; die beiden Unterarme sind hier neu, und
/// mit ihnen ihr Messhinweis.
library;

/// Die drei Karten des Formulars — zugleich die Reihenfolge, in der
/// [Umfang.values] läuft.
///
/// Fünfzehn Zahlenfelder in einer Liste scrollen sich schlecht.
enum UmfangsGruppe { arme, rumpf, beine }

/// Ein Körpermaß.
///
/// Die Reihenfolge von [values] ist die des Formulars: Arme, Rumpf, Beine —
/// beim Messen arbeitet man mit dem Maßband den Körper hinunter. Die
/// Übersicht sortiert anders, dafür gibt es [istWichtig].
enum Umfang {
  oberarmRechtsLocker('upperArmRightRelaxed'),
  oberarmRechtsAngespannt('upperArmRightFlexed'),
  oberarmLinksLocker('upperArmLeftRelaxed'),
  oberarmLinksAngespannt('upperArmLeftFlexed'),
  unterarmRechts('forearmRight'),
  unterarmLinks('forearmLeft'),
  brust('chest'),
  schultern('shoulders'),
  taille('waist'),
  hals('neck'),
  huefte('hips'),
  // Die Rohwerte `thigh` und `calf` bleiben bei den **rechten** Maßen.
  // Tims abgelegte und exportierte Dateien kennen nur diese beiden Schlüssel;
  // wanderten sie nach links, läsen sich alte Messungen als die falsche Seite
  // — und das sähe niemand, weil beide Zahlen plausibel sind.
  oberschenkelRechts('thigh'),
  oberschenkelLinks('thighLeft'),
  wadeRechts('calf'),
  wadeLinks('calfLeft');

  const Umfang(this.schluessel);

  /// Der stabile Schlüssel in Datenbank und Importdatei.
  ///
  /// Nicht der Dart-Name: Der darf sich ändern, ohne dass abgelegte Zeilen
  /// ihre Bedeutung verlieren.
  final String schluessel;

  /// Der Name, unter dem das Maß in Formular, Liste und Diagramm steht.
  String get deutsch => switch (this) {
    Umfang.oberarmRechtsLocker => 'Oberarm rechts, locker',
    Umfang.oberarmRechtsAngespannt => 'Oberarm rechts, angespannt',
    Umfang.oberarmLinksLocker => 'Oberarm links, locker',
    Umfang.oberarmLinksAngespannt => 'Oberarm links, angespannt',
    Umfang.unterarmRechts => 'Unterarm rechts',
    Umfang.unterarmLinks => 'Unterarm links',
    Umfang.brust => 'Brust',
    Umfang.schultern => 'Schultern',
    // Die Messstelle gehört zum Namen: Eine Taille lässt sich an drei Stellen
    // messen, und drei Stellen ergäben drei Verläufe.
    Umfang.taille => 'Taille (Nabel)',
    Umfang.hals => 'Hals',
    Umfang.huefte => 'Hüfte',
    Umfang.oberschenkelRechts => 'Oberschenkel rechts',
    Umfang.oberschenkelLinks => 'Oberschenkel links',
    Umfang.wadeRechts => 'Wade rechts',
    Umfang.wadeLinks => 'Wade links',
  };

  /// Für das Ziel „Oberarm und Brust wachsen, Taille bleibt" ist bei der
  /// Taille die kleinere Zahl der Fortschritt.
  ///
  /// Die Hüfte gehört ausdrücklich nicht dazu: Sie misst mit, was am Gesäß
  /// aufgebaut wird.
  bool get wenigerIstBesser => this == Umfang.taille;

  /// Das Gegenstück: dieselbe Messart auf der **anderen Seite**.
  ///
  /// Locker und angespannt desselben Arms sind kein Paar — gemeint ist die
  /// Seitendifferenz, nicht der Anspannungszuwachs. Brust, Schultern, Taille,
  /// Hals und Hüfte gibt es nur einmal am Körper.
  Umfang? get partner => switch (this) {
    Umfang.oberarmRechtsLocker => Umfang.oberarmLinksLocker,
    Umfang.oberarmLinksLocker => Umfang.oberarmRechtsLocker,
    Umfang.oberarmRechtsAngespannt => Umfang.oberarmLinksAngespannt,
    Umfang.oberarmLinksAngespannt => Umfang.oberarmRechtsAngespannt,
    Umfang.unterarmRechts => Umfang.unterarmLinks,
    Umfang.unterarmLinks => Umfang.unterarmRechts,
    Umfang.oberschenkelRechts => Umfang.oberschenkelLinks,
    Umfang.oberschenkelLinks => Umfang.oberschenkelRechts,
    Umfang.wadeRechts => Umfang.wadeLinks,
    Umfang.wadeLinks => Umfang.wadeRechts,
    Umfang.brust ||
    Umfang.schultern ||
    Umfang.taille ||
    Umfang.hals ||
    Umfang.huefte => null,
  };

  /// Wo und wie gemessen wird — ein Satz je Maß.
  ///
  /// Je Maß ein eigener: Ein Sammelsatz, fünfzehnmal wiederholt, hilft beim
  /// Messen nicht, und rechts und links unterscheiden sich gerade darin,
  /// welches Bein belastet ist.
  String get messhinweis => switch (this) {
    Umfang.oberarmRechtsLocker =>
      'Rechter Arm hängt locker herab, Maßband an der dicksten Stelle '
          'zwischen Schulter und Ellenbogen.',
    Umfang.oberarmRechtsAngespannt =>
      'Rechter Arm im rechten Winkel, Bizeps angespannt, Maßband um die '
          'höchste Wölbung.',
    Umfang.oberarmLinksLocker =>
      'Linker Arm hängt locker herab, Maßband an der dicksten Stelle '
          'zwischen Schulter und Ellenbogen.',
    Umfang.oberarmLinksAngespannt =>
      'Linker Arm im rechten Winkel, Bizeps angespannt, Maßband um die '
          'höchste Wölbung.',
    // Für die beiden Unterarme gibt es in der Swift-Fassung keine Vorlage;
    // diese zwei Sätze sind neu.
    Umfang.unterarmRechts =>
      'Rechter Unterarm an der dicksten Stelle kurz unterhalb des '
          'Ellenbogens, Hand locker geöffnet.',
    Umfang.unterarmLinks =>
      'Linker Unterarm an der dicksten Stelle kurz unterhalb des '
          'Ellenbogens, Hand locker geöffnet.',
    Umfang.brust =>
      'Maßband waagerecht auf Höhe der Brustwarzen, am Ende einer normalen '
          'Ausatmung.',
    Umfang.schultern =>
      'Maßband waagerecht um die breiteste Stelle der Schultern, Arme hängen '
          'entspannt.',
    Umfang.taille =>
      'Maßband auf Nabelhöhe, locker stehen und den Bauch nicht einziehen.',
    Umfang.hals =>
      'Maßband unterhalb des Kehlkopfs um den Hals, leicht schräg nach '
          'hinten, nicht einschnüren.',
    Umfang.huefte =>
      'Maßband um die stärkste Stelle des Gesäßes, Füße geschlossen.',
    Umfang.oberschenkelRechts =>
      'Rechtes Bein belastet, Maßband eine Handbreit unter dem Schritt um '
          'die dickste Stelle.',
    Umfang.oberschenkelLinks =>
      'Linkes Bein belastet, Maßband eine Handbreit unter dem Schritt um die '
          'dickste Stelle.',
    Umfang.wadeRechts =>
      'Rechte Wade an der dicksten Stelle, Gewicht gleichmäßig auf beiden '
          'Füßen.',
    Umfang.wadeLinks =>
      'Linke Wade an der dicksten Stelle, Gewicht gleichmäßig auf beiden '
          'Füßen.',
  };

  /// Die Karte des Formulars, auf der das Maß steht. Der Unterarm gehört zu
  /// den Armen.
  UmfangsGruppe get gruppe => switch (this) {
    Umfang.oberarmRechtsLocker ||
    Umfang.oberarmRechtsAngespannt ||
    Umfang.oberarmLinksLocker ||
    Umfang.oberarmLinksAngespannt ||
    Umfang.unterarmRechts ||
    Umfang.unterarmLinks => UmfangsGruppe.arme,
    Umfang.brust ||
    Umfang.schultern ||
    Umfang.taille ||
    Umfang.hals ||
    Umfang.huefte => UmfangsGruppe.rumpf,
    Umfang.oberschenkelRechts ||
    Umfang.oberschenkelLinks ||
    Umfang.wadeRechts ||
    Umfang.wadeLinks => UmfangsGruppe.beine,
  };

  /// Ob das Maß in der Übersicht unter „Für dein Ziel am wichtigsten" steht.
  ///
  /// Der locker gemessene Oberarm gehört nicht dazu: Gewachsen ist der Arm,
  /// wenn er angespannt wächst; locker schwankt mit Tagesform und Haltung.
  bool get istWichtig => switch (this) {
    Umfang.oberarmRechtsAngespannt ||
    Umfang.oberarmLinksAngespannt ||
    Umfang.brust ||
    Umfang.taille => true,
    // Ausgeschrieben statt `_`: Käme ein sechzehntes Maß dazu, zeigt der
    // Analyzer hierher, statt es stillschweigend nach Grau zu sortieren.
    Umfang.oberarmRechtsLocker ||
    Umfang.oberarmLinksLocker ||
    Umfang.unterarmRechts ||
    Umfang.unterarmLinks ||
    Umfang.schultern ||
    Umfang.hals ||
    Umfang.huefte ||
    Umfang.oberschenkelRechts ||
    Umfang.oberschenkelLinks ||
    Umfang.wadeRechts ||
    Umfang.wadeLinks => false,
  };

  /// Das Maß zu einem abgelegten [schluessel], oder `null`, wenn der
  /// Schlüssel zu keinem gehört.
  ///
  /// Pflicht und nicht Beiwerk: Die Ablage schreibt [schluessel] in die
  /// Spalte `mass`, ohne den Weg zurück ließe sich keine Zeile lesen. Ein
  /// unbekannter Schlüssel ergibt `null` und keine Ausnahme — eine fremde
  /// oder ältere Importdatei darf das Lesen nicht abbrechen.
  static Umfang? vonSchluessel(String schluessel) =>
      _nachSchluessel[schluessel];

  static final Map<String, Umfang> _nachSchluessel = {
    for (final mass in Umfang.values) mass.schluessel: mass,
  };
}
