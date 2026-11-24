import 'dart:convert';

import 'package:flutter/services.dart';

/// Pflichtangabe der RepDB-Lizenz (`assets/exercises/LICENSE-DATA.md`,
/// Punkt 2): Die Bewegungsbilder und Übungsdaten sind RepDB-Material, und
/// ein sichtbarer Hinweis darauf ist die Bedingung für ihre Nutzung — keine
/// Höflichkeit. **Darf nicht wegfallen und nicht umformuliert werden.**
///
/// Sie steht **hier**, nicht als Zeichenkette in einem Schirm: Das Mehr-Menü
/// zeigt genau diese Konstante, und jeder Schirm, der ein Bild zeigt, kann
/// sie über [Uebungsbild.attribution] bekommen. Eine zweite Fassung
/// derselben Zeichenkette liefe auseinander, ohne dass es jemand merkt.
/// `scripts/exercises-convert.mjs` führt dieselbe Zeichenkette;
/// `test/gym/uebungsbilder_test.dart` hält beide zusammen.
const String repdbAttribution = 'Exercise data by RepDB (repdb.co)';

/// Das Bewegungsbild zu einer Übung der Bibliothek (`ExerciseLibrary` —
/// Anker wie Erzeugte, #551).
///
/// Eine Übung ohne Bild hat **keinen** [Uebungsbild] — sie bleibt mit Name,
/// Wiederholungen und Technik-Hinweis aus der Bibliothek benutzbar. Ein Bild
/// gibt es nur, wo die Zuordnung sicher ist: bei den Ankern über
/// `scripts/exercises-mapping.mjs`, bei den Erzeugten über die eigene
/// Asset-Zeile (Zeilen-ID = unsere ID). Ein Bild einer anderen Bewegung
/// wäre schlimmer als keins.
///
/// Die Bilder gehören RepDB und stehen unter deren Lizenz — nur in der App
/// zeigen, nicht weitergeben, nicht als Vorlage für generative Modelle
/// verwenden.
class Uebungsbild {
  const Uebungsbild({
    required this.exerciseId,
    required this.repdbId,
    required this.repdbName,
    required this.start,
    this.peak,
    this.approximate = false,
    this.note,
  });

  /// Unsere ID aus `ExerciseCatalog`.
  final String exerciseId;

  /// Die ID der Übung im RepDB-Datensatz.
  final String repdbId;

  /// Englischer Name im Datensatz. Nur zur Nachvollziehbarkeit — angezeigt
  /// wird der Name aus dem Katalog.
  final String repdbName;

  /// Asset-Pfad des ersten Bildes (`Image.asset`). Bei Übungen, die ein
  /// einzelnes Bild haben (Halteübungen), ist es das einzige.
  final String start;

  /// Asset-Pfad des Bildes am Umkehrpunkt, `null` bei Einzelbild.
  final String? peak;

  /// Das Bild trifft die Übung nicht genau: Die Bewegung ist dieselbe, Gerät
  /// oder Aufbau weichen ab. Dann ist es ein Anhaltspunkt und keine
  /// Vorlage — **der Schirm muss das sagen**, am besten mit [note].
  final bool approximate;

  /// Ein Satz dazu, worin die Abweichung besteht (bei [approximate]), oder
  /// ein Hinweis zum Bild. Deutsch, für die Anzeige gedacht. `null`, wenn es
  /// nichts zu sagen gibt.
  final String? note;

  /// Alle Bilder in der Reihenfolge Start, Umkehrpunkt.
  List<String> get frames => [start, ?peak];

  /// Die Pflichtangabe der Lizenz, siehe [repdbAttribution].
  String get attribution => repdbAttribution;

  @override
  bool operator ==(Object other) =>
      other is Uebungsbild &&
      other.exerciseId == exerciseId &&
      other.repdbId == repdbId &&
      other.repdbName == repdbName &&
      other.start == start &&
      other.peak == peak &&
      other.approximate == approximate &&
      other.note == note;

  @override
  int get hashCode => Object.hash(
    exerciseId,
    repdbId,
    repdbName,
    start,
    peak,
    approximate,
    note,
  );

  @override
  String toString() => 'Uebungsbild($exerciseId → $repdbId)';
}

/// Die Bewegungsbilder aller Katalogübungen, die eines haben.
///
/// Gelesen wird `assets/exercises/exercises.json`, das
/// `scripts/exercises-asset.mjs` erzeugt. [laden] liest die Datei einmal;
/// [fuer] ist danach eine reine Nachschlage-Abfrage ohne Rechnung — geeignet,
/// um den Wert in einem Provider zu halten (CLAUDE.md, Datenschicht Regel 2).
///
/// **Ein Schirm liest dafür keinen `AsyncValue`:** Wer [laden] aufruft,
/// bekommt entweder ein fertiges Objekt oder eine Ausnahme. Ein Asset, das
/// nicht zur Erwartung passt (andere Spalten, andere Fassung), **wirft**
/// statt Bilder falsch zuzuordnen; wer die App trotzdem ohne Bilder starten
/// will, fängt das an einer Stelle und nimmt [leer].
class Uebungsbilder {
  Uebungsbilder._(this._bilder);

  /// Keine Bilder. Für den Fall, dass das Asset nicht lesbar ist: Jede
  /// Übung bleibt ohne Bild benutzbar.
  static final Uebungsbilder leer = Uebungsbilder._(const {});

  /// Dieselben Spalten wie `FIELDS` in `scripts/exercises-convert.mjs`.
  /// Weicht das Asset ab, wirft [parse], statt Spalten zu verwechseln.
  static const List<String> erwarteteSpalten = [
    'id',
    'en',
    'de',
    'terms',
    'primary',
    'secondary',
    'equipment',
    'compound',
    'unilateral',
    'images',
    'steps',
    'tips',
    'assisted',
  ];

  /// Wo das Asset liegt.
  static const String assetVerzeichnis = 'assets/exercises/';

  static const String _assetDatei = '${assetVerzeichnis}exercises.json';

  final Map<String, Uebungsbild> _bilder;

  /// Liest das Asset aus dem Bündel (`rootBundle` im Betrieb).
  static Future<Uebungsbilder> laden(AssetBundle bundle) async =>
      parse(await bundle.loadString(_assetDatei));

  /// Das Bild zu einer Übung des Katalogs, oder `null`, wenn es keines gibt.
  Uebungsbild? fuer(String exerciseId) => _bilder[exerciseId];

  /// Unsere IDs, zu denen es ein Bild gibt.
  Iterable<String> get exerciseIds => _bilder.keys;

  /// Liest den Text von `exercises.json`. Wirft [FormatException], wenn die
  /// Spalten nicht [erwarteteSpalten] sind, eine Zuordnung auf eine Übung
  /// zeigt, die nicht im Asset steht, oder die Form eines Bildes unbekannt
  /// ist.
  static Uebungsbilder parse(String text) {
    final json = jsonDecode(text) as Map<String, dynamic>;

    final spalten = (json['fields'] as List<dynamic>).cast<String>();
    if (spalten.length != erwarteteSpalten.length ||
        !_gleicheReihenfolge(spalten, erwarteteSpalten)) {
      throw FormatException(
        'exercises.json hat die Spalten $spalten, erwartet '
        '$erwarteteSpalten — Asset und App passen nicht zusammen.',
      );
    }
    final spalteId = spalten.indexOf('id');
    final spalteEn = spalten.indexOf('en');
    final spalteBilder = spalten.indexOf('images');

    final zeilen = <String, List<dynamic>>{
      for (final zeile in (json['exercises'] as List<dynamic>))
        (zeile as List<dynamic>)[spalteId] as String: zeile,
    };

    final bilder = <String, Uebungsbild>{};
    final zuordnung = json['media'] as Map<String, dynamic>;
    for (final eintrag in zuordnung.entries) {
      final werte = eintrag.value as Map<String, dynamic>;
      final repdbId = werte['repdb'] as String;
      final zeile = zeilen[repdbId];
      if (zeile == null) {
        throw FormatException(
          'Zuordnung ${eintrag.key} zeigt auf $repdbId, und die steht nicht '
          'im Asset.',
        );
      }
      final (start, peak) = _bildDateien(repdbId, zeile[spalteBilder]);
      bilder[eintrag.key] = Uebungsbild(
        exerciseId: eintrag.key,
        repdbId: repdbId,
        repdbName: zeile[spalteEn] as String,
        start: start,
        peak: peak,
        approximate: werte['approximate'] == true,
        note: werte['note'] as String?,
      );
    }

    // Der Zusatz für die Bibliothek (#551, Spec 7.2): Jede Zeile, auf die
    // **keine** `media`-Zuordnung zeigt, ist das Bild der gleichnamigen
    // Bibliotheksübung — Zeilen-ID = unsere ID, nie ungefähr, ohne Satz.
    // Die Anker-Zeilen (media-Ziele) bleiben Anker-Bilder und erzeugen kein
    // zweites Bild unter der RepDB-ID.
    final ankerZeilen = <String>{
      for (final wert in zuordnung.values)
        (wert as Map<String, dynamic>)['repdb'] as String,
    };
    for (final eintrag in zeilen.entries) {
      if (ankerZeilen.contains(eintrag.key)) continue;
      final (start, peak) = _bildDateien(
        eintrag.key,
        eintrag.value[spalteBilder],
      );
      bilder[eintrag.key] = Uebungsbild(
        exerciseId: eintrag.key,
        repdbId: eintrag.key,
        repdbName: eintrag.value[spalteEn] as String,
        start: start,
        peak: peak,
      );
    }
    return Uebungsbilder._(Map.unmodifiable(bilder));
  }

  /// Die Asset-Pfade `(start, peak)` aus der `images`-Spalte einer Zeile.
  /// Bildform `main` oder `start`+`peak` wie bisher, jede andere wirft.
  static (String, String?) _bildDateien(String id, Object? roh) {
    final dateien = (roh as Map<String, dynamic>).cast<String, String>();
    final String start;
    String? peak;
    if (dateien.length == 1 && dateien.containsKey('main')) {
      start = dateien['main']!;
    } else if (dateien.length == 2 &&
        dateien.containsKey('start') &&
        dateien.containsKey('peak')) {
      start = dateien['start']!;
      peak = dateien['peak'];
    } else {
      throw FormatException('Übung $id hat unbekannte Bildform $dateien.');
    }
    return (
      '${assetVerzeichnis}images/$start',
      peak == null ? null : '${assetVerzeichnis}images/$peak',
    );
  }

  static bool _gleicheReihenfolge(List<String> a, List<String> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
