import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/gym/uebungsbilder.dart';

/// Die Bewegungsbilder der **Bibliothek** (#551, Spec 7.2 und 12.3; Plan
/// Task 3.1): `Uebungsbilder.parse` wächst um einen Fall — jede Asset-Zeile,
/// auf die **keine** `media`-Zuordnung zeigt, ist das Bild der gleichnamigen
/// Bibliotheksübung (Zeilen-ID = unsere ID, `approximate: false`, keine
/// `note`). Die Anker-Zeilen (auf die `media` zeigt) bleiben Anker-Bilder
/// und erzeugen **kein zweites** Bild unter der RepDB-ID.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Hält der
/// Implementierende eine Erwartung für falsch, wird das gemeldet, nicht
/// korrigiert.
///
/// Zwei Sorten Fälle:
///
/// 1. **`parse`-Zusatz am kleinen Asset** — rot, bis 7.2 gebaut ist.
/// 2. **Wächter über das echte Asset** — von Anfang an **grün**: Sie prüfen
///    Behauptungen über das Asset und die erzeugte Bibliothek, kein noch zu
///    bauendes Verhalten (`CLAUDE.md`, „Ein Wächtertest ist von Anfang an
///    grün").
///
/// `uebungsbilder_test.dart` bleibt unverändert und gilt weiter — vor allem
/// „genau diese beiden sind bewusst ungefähr" (`tibialisRaise`,
/// `cableRowClose`).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Das echte Asset von der Platte. `flutter test` läuft in `app/`.
  Map<String, dynamic> asset() =>
      jsonDecode(File('assets/exercises/exercises.json').readAsStringSync())
          as Map<String, dynamic>;

  group('Der parse-Zusatz (Spec 7.2) — kleines Asset', () {
    /// Ein Asset im kleinsten Format: eine Anker-Zeile (`repdb-bank`, Ziel
    /// der `media`-Zuordnung von `benchPress`) und eine freie Zeile
    /// (`row-zwei`), auf die nichts zeigt. Alle Werte erfunden.
    String klein({Object? freieBilder}) => jsonEncode({
      'fields': Uebungsbilder.erwarteteSpalten,
      'media': {
        'benchPress': {'de': 'x', 'repdb': 'repdb-bank'},
      },
      'exercises': [
        [
          'repdb-bank',
          'Bench Press',
          'Bankdrücken',
          <String>[],
          <String>[],
          <String>[],
          'barbell',
          true,
          false,
          {'start': 'b-1.webp', 'peak': 'b-2.webp'},
          {'en': <String>[], 'de': <String>[]},
          {'en': <String>[], 'de': <String>[]},
          false,
        ],
        [
          'row-zwei',
          'Row Two',
          'Zeile Zwei',
          <String>[],
          <String>[],
          <String>[],
          'cable',
          false,
          false,
          freieBilder ?? {'start': 'z-1.webp', 'peak': 'z-2.webp'},
          {'en': <String>[], 'de': <String>[]},
          {'en': <String>[], 'de': <String>[]},
          false,
        ],
      ],
    });

    test('eine Zeile ohne media-Ziel wird zum Bild unter der Zeilen-ID — '
        'nicht ungefähr, ohne Satz', () {
      final bilder = Uebungsbilder.parse(klein());
      final bild = bilder.fuer('row-zwei');

      expect(
        bild,
        isNotNull,
        reason:
            'Spec 7.2: Jede Zeile, auf die keine media-Zuordnung zeigt, ist '
            'das Bild der gleichnamigen Bibliotheksübung.',
      );
      expect(bild!.exerciseId, 'row-zwei');
      expect(bild.repdbId, 'row-zwei', reason: 'Zeilen-ID = unsere ID');
      expect(bild.repdbName, 'Row Two');
      expect(bild.start, 'assets/exercises/images/z-1.webp');
      expect(bild.peak, 'assets/exercises/images/z-2.webp');
      expect(
        bild.approximate,
        isFalse,
        reason: 'Ein erzeugtes Bild ist nie `approximate` (Spec 7.2)',
      );
      expect(bild.note, isNull);
    });

    test('eine Zeile mit media-Ziel erzeugt kein zweites Bild unter der '
        'RepDB-ID', () {
      final bilder = Uebungsbilder.parse(klein());

      expect(
        bilder.fuer('benchPress'),
        isNotNull,
        reason: 'Das Anker-Bild bleibt, wie es war',
      );
      expect(
        bilder.fuer('repdb-bank'),
        isNull,
        reason:
            'Die Anker-Zeile ist schon das Bild von `benchPress` — ein '
            'zweites unter der RepDB-ID gäbe dieselbe Datei zweimal aus '
            '(Spec 7.2)',
      );
    });

    test('eine freie Zeile mit Einzelbild (`main`) hat keinen Umkehrpunkt', () {
      final bild = Uebungsbilder.parse(
        klein(freieBilder: {'main': 'z.webp'}),
      ).fuer('row-zwei');

      expect(bild, isNotNull);
      expect(bild!.start, 'assets/exercises/images/z.webp');
      expect(bild.peak, isNull);
      expect(bild.frames, ['assets/exercises/images/z.webp']);
    });

    test('`fuer(\'gibtEsNicht\')` bleibt null', () {
      expect(Uebungsbilder.parse(klein()).fuer('gibtEsNicht'), isNull);
    });

    test('eine unbekannte Bildform einer freien Zeile wirft', () {
      expect(
        () => Uebungsbilder.parse(klein(freieBilder: {'start': 'z.webp'})),
        throwsFormatException,
        reason:
            'Bildform `main` oder `start`+`peak`, jede andere wirft — auch '
            'im neuen Fall (Spec 7.2)',
      );
    });
  });

  group('Wächter — Asset und Bibliothek passen zusammen '
      '(von Anfang an grün, Spec 12.3)', () {
    test('jede Asset-Zeile ist Ziel einer media-Zuordnung oder hat eine '
        'gleichnamige Bibliotheksübung', () {
      final json = asset();
      final spalten = (json['fields'] as List<dynamic>).cast<String>();
      final spalteId = spalten.indexOf('id');
      final spalteDe = spalten.indexOf('de');
      final ziele = {
        for (final wert in (json['media'] as Map<String, dynamic>).values)
          (wert as Map<String, dynamic>)['repdb'] as String,
      };

      for (final zeile in json['exercises'] as List<dynamic>) {
        final werte = zeile as List<dynamic>;
        final id = werte[spalteId] as String;
        if (ziele.contains(id)) continue;
        final uebung = ExerciseLibrary.byId(id);
        expect(
          uebung,
          isNotNull,
          reason:
              '$id: weder media-Ziel noch Bibliotheksübung — die Zeile wäre '
              'ein Bild ohne Übung.',
        );
        expect(
          uebung!.name,
          werte[spalteDe],
          reason:
              '$id heißt in der Bibliothek anders als im Asset — das Bild '
              'gehörte zu einer anderen Übung.',
        );
      }
    });

    test('jede erzeugte Übung hat eine Zeile — und damit ein Bild', () {
      final json = asset();
      final spalten = (json['fields'] as List<dynamic>).cast<String>();
      final spalteId = spalten.indexOf('id');
      final zeilenIds = {
        for (final zeile in json['exercises'] as List<dynamic>)
          (zeile as List<dynamic>)[spalteId] as String,
      };

      for (final id in ExerciseLibrary.all.keys) {
        if (ExerciseLibrary.isCatalog(id)) continue;
        expect(
          zeilenIds,
          contains(id),
          reason:
              '$id steht in der Bibliothek, aber nicht im Asset — die Übung '
              'bliebe ohne Bild, ohne dass es jemand merkt.',
        );
      }
    });

    test('jede Bilddatei jeder Zeile existiert und ist nicht leer', () {
      // Nur Größe, nicht Inhalt (Plan Task 3.1).
      final json = asset();
      final spalten = (json['fields'] as List<dynamic>).cast<String>();
      final spalteId = spalten.indexOf('id');
      final spalteBilder = spalten.indexOf('images');

      for (final zeile in json['exercises'] as List<dynamic>) {
        final werte = zeile as List<dynamic>;
        final id = werte[spalteId] as String;
        final dateien = (werte[spalteBilder] as Map<String, dynamic>)
            .cast<String, String>();
        expect(dateien, isNotEmpty, reason: '$id: Zeile ohne Bilddatei');
        for (final name in dateien.values) {
          final datei = File('assets/exercises/images/$name');
          expect(datei.existsSync(), isTrue, reason: '$id: $name fehlt');
          expect(
            datei.lengthSync(),
            greaterThan(0),
            reason: '$id: $name ist leer',
          );
        }
      }
    });

    test('kein Bild ohne Zeile: jede Datei im Bildordner wird von einer '
        'Zeile genannt', () {
      final json = asset();
      final spalten = (json['fields'] as List<dynamic>).cast<String>();
      final spalteBilder = spalten.indexOf('images');
      final genannt = <String>{
        for (final zeile in json['exercises'] as List<dynamic>)
          ...((zeile as List<dynamic>)[spalteBilder] as Map<String, dynamic>)
              .cast<String, String>()
              .values,
      };

      final dateien = Directory('assets/exercises/images')
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .where((name) => !name.startsWith('.'));
      for (final name in dateien) {
        expect(
          genannt,
          contains(name),
          reason:
              '$name liegt im Bildordner, aber keine Zeile nennt es — totes '
              'Gewicht im Bündel oder eine verrutschte Zuordnung.',
        );
      }
    });

    test('ein erzeugtes Bild ist nie `approximate` — die beiden bewussten '
        'Ausnahmen sind Anker', () {
      // `tibialisRaise` und `cableRowClose` nagelt `uebungsbilder_test.dart`
      // fest; hier steht die Gegenseite: Kein erzeugtes kommt dazu.
      final bilder = Uebungsbilder.parse(
        File('assets/exercises/exercises.json').readAsStringSync(),
      );
      for (final id in bilder.exerciseIds) {
        if (ExerciseLibrary.isCatalog(id)) continue;
        expect(
          bilder.fuer(id)!.approximate,
          isFalse,
          reason: '$id: ein erzeugtes Bild ist nie ungefähr (Spec 7.2)',
        );
        expect(bilder.fuer(id)!.note, isNull, reason: id);
      }
    });

  });

  group('Der parse-Zusatz am echten Asset (rot, bis 7.2 gebaut ist)', () {
    test('jede Bibliotheksübung hat ein Bild (`fuer(id) != null`)', () {
      // Der eine Satz, der 3.1 mit 3.4 verbindet: Die Icon-Logik der Auswahl
      // (latent, Nachtrag 17 Nr. 1) hängt an genau dieser Frage.
      final bilder = Uebungsbilder.parse(
        File('assets/exercises/exercises.json').readAsStringSync(),
      );
      for (final id in ExerciseLibrary.all.keys) {
        expect(
          bilder.fuer(id),
          isNotNull,
          reason: '$id: jede Zeile des Assets trägt ihr Bild (Spec 7.2, 12.3)',
        );
      }
    });
  });
}
