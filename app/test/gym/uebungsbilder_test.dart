import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/gym/uebungsbilder.dart';

/// Die RepDB-Bewegungsbilder (#38): das Asset, die Zuordnung unserer
/// Katalogübungen auf RepDB-Übungen und die Lizenzpflicht.
///
/// Das Asset entsteht in `scripts/exercises-asset.mjs`; dessen Umwandlung
/// prüft `scripts/test/exercises-convert.test.mjs`. Hier steht, was nur die
/// App prüfen kann: dass Katalog, Zuordnung und Dateien zusammenpassen.
///
/// Geschrieben vom selben Agenten wie die Implementierung, auf Wunsch von
/// Tim — die Rollentrennung aus `CLAUDE.md` gilt hier nicht.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Das Asset von der Platte. `flutter test` läuft in `app/`.
  Map<String, dynamic> asset() =>
      jsonDecode(File('assets/exercises/exercises.json').readAsStringSync())
          as Map<String, dynamic>;

  /// Übungen des Katalogs, die bewusst kein Bild haben. Heute: keine. Kommt
  /// eine dazu, steht sie hier mit Begründung — nicht stillschweigend.
  const bewusstOhneBild = <String>{};

  group('Zuordnung', () {
    test('jede Katalogübung hat ein Bild oder steht bewusst ohne da', () {
      final zuordnung = (asset()['media'] as Map<String, dynamic>).keys.toSet();
      final ohne = ExerciseCatalog.all.keys.toSet().difference(zuordnung);
      expect(
        ohne,
        bewusstOhneBild,
        reason:
            'Übungen ohne Zuordnung. Neue Katalogübung? Zuordnung in '
            'scripts/exercises-mapping.mjs ergänzen und das Asset neu '
            'erzeugen — oder hier mit Begründung eintragen.',
      );
    });

    test(
      'jede Zuordnung gehört zu einer Katalogübung, mit demselben Namen',
      () {
        final zuordnung = asset()['media'] as Map<String, dynamic>;
        for (final eintrag in zuordnung.entries) {
          final uebung = ExerciseCatalog.all[eintrag.key];
          expect(
            uebung,
            isNotNull,
            reason: '${eintrag.key} steht nicht im Katalog (umbenannt?)',
          );
          expect(
            (eintrag.value as Map<String, dynamic>)['de'],
            uebung!.name,
            reason:
                '${eintrag.key} heißt im Katalog anders — die Zuordnung wurde '
                'für eine andere Übung geprüft.',
          );
        }
      },
    );

    test('jede zugeordnete RepDB-ID steht im Datensatz', () {
      // Gäbe es sie nicht, verwaiste die Zuordnung beim nächsten Update
      // unbemerkt, und die Übung bliebe ohne Bild, ohne dass jemand es merkt.
      final json = asset();
      final ids = {
        for (final zeile in json['exercises'] as List<dynamic>)
          (zeile as List<dynamic>).first as String,
      };
      final zuordnung = json['media'] as Map<String, dynamic>;
      for (final eintrag in zuordnung.entries) {
        final repdb = (eintrag.value as Map<String, dynamic>)['repdb'];
        expect(ids, contains(repdb), reason: '${eintrag.key} → $repdb');
      }
    });

    test('ein ungefährer Treffer sagt, worin er abweicht', () {
      final bilder = Uebungsbilder.parse(
        File('assets/exercises/exercises.json').readAsStringSync(),
      );
      for (final id in bilder.exerciseIds) {
        final bild = bilder.fuer(id)!;
        if (bild.approximate) {
          expect(bild.note, isNotEmpty, reason: '$id ist ungefähr, ohne Satz');
        }
      }
      // Genau diese beiden sind bewusst ungefähr; ein dritter soll nicht
      // unbemerkt dazukommen.
      expect(
        bilder.exerciseIds.where((id) => bilder.fuer(id)!.approximate).toSet(),
        {'tibialisRaise', 'cableRowClose'},
      );
    });
  });

  group('Asset', () {
    test('jede Bilddatei existiert und ist nicht leer', () {
      final bilder = Uebungsbilder.parse(
        File('assets/exercises/exercises.json').readAsStringSync(),
      );
      for (final id in bilder.exerciseIds) {
        for (final pfad in bilder.fuer(id)!.frames) {
          final datei = File(pfad);
          expect(datei.existsSync(), isTrue, reason: '$id: $pfad fehlt');
          expect(datei.lengthSync(), greaterThan(0), reason: '$id: $pfad leer');
        }
      }
    });

    test('jeder Muskelcode im Asset ist eine Muskelgruppe der App', () {
      final codes = {for (final m in Muscle.values) m.code};
      final spalten = (asset()['fields'] as List<dynamic>).cast<String>();
      for (final zeile in asset()['exercises'] as List<dynamic>) {
        final werte = zeile as List<dynamic>;
        for (final spalte in ['primary', 'secondary']) {
          for (final code in werte[spalten.indexOf(spalte)] as List<dynamic>) {
            expect(codes, contains(code), reason: '${werte.first}: $code');
          }
        }
      }
    });

    test('die Lizenzdatei liegt neben den Daten', () {
      final lizenz = File('assets/exercises/LICENSE-DATA.md');
      expect(lizenz.existsSync(), isTrue);
      expect(lizenz.readAsStringSync(), contains('RepDB'));
    });

    test(
      'das Asset ist im Bündel deklariert: Daten und Bilder laden',
      () async {
        // `rootBundle` kennt nur, was `pubspec.yaml` unter `assets:` führt. Ein
        // Eintrag für `images/` fehlt leicht, weil er nicht rekursiv gilt.
        final bilder = await Uebungsbilder.laden(rootBundle);
        expect(bilder.exerciseIds, isNotEmpty);
        for (final id in bilder.exerciseIds) {
          for (final pfad in bilder.fuer(id)!.frames) {
            final bytes = await rootBundle.load(pfad);
            expect(bytes.lengthInBytes, greaterThan(0), reason: pfad);
          }
        }
      },
    );
  });

  group('Lesen', () {
    /// Ein Asset im kleinsten Format, mit einer Zuordnung.
    String klein({List<String>? spalten, Object? bilder, String repdb = 'a'}) =>
        jsonEncode({
          'fields': spalten ?? Uebungsbilder.erwarteteSpalten,
          'media': {
            'benchPress': {'de': 'x', 'repdb': repdb},
          },
          'exercises': [
            [
              'a',
              'Alpha',
              'Alpha',
              <String>[],
              <String>[],
              <String>[],
              'barbell',
              true,
              false,
              bilder ?? {'start': 's.webp', 'peak': 'p.webp'},
              {'en': <String>[], 'de': <String>[]},
              {'en': <String>[], 'de': <String>[]},
              false,
            ],
          ],
        });

    test('Start und Umkehrpunkt werden zu Asset-Pfaden', () {
      final bild = Uebungsbilder.parse(klein()).fuer('benchPress')!;
      expect(bild.start, 'assets/exercises/images/s.webp');
      expect(bild.peak, 'assets/exercises/images/p.webp');
      expect(bild.frames, hasLength(2));
      expect(bild.approximate, isFalse);
    });

    test('ein Einzelbild hat keinen Umkehrpunkt', () {
      final bild = Uebungsbilder.parse(klein(bilder: {'main': 'm.webp'}))
          .fuer('benchPress')!;
      expect(bild.start, 'assets/exercises/images/m.webp');
      expect(bild.peak, isNull);
      expect(bild.frames, ['assets/exercises/images/m.webp']);
    });

    test('eine Übung ohne Zuordnung hat kein Bild', () {
      expect(Uebungsbilder.parse(klein()).fuer('gibtEsNicht'), isNull);
      expect(Uebungsbilder.leer.fuer('benchPress'), isNull);
    });

    test('abweichende Spalten werfen, statt zu verwechseln', () {
      final vertauscht = [...Uebungsbilder.erwarteteSpalten]..swap(1, 2);
      expect(
        () => Uebungsbilder.parse(klein(spalten: vertauscht)),
        throwsFormatException,
      );
      expect(
        () => Uebungsbilder.parse(
          klein(spalten: Uebungsbilder.erwarteteSpalten.sublist(1)),
        ),
        throwsFormatException,
      );
    });

    test('eine Zuordnung auf eine fehlende Übung wirft', () {
      expect(
        () => Uebungsbilder.parse(klein(repdb: 'gibt-es-nicht')),
        throwsFormatException,
      );
    });

    test('eine unbekannte Bildform wirft', () {
      expect(
        () => Uebungsbilder.parse(klein(bilder: {'start': 's.webp'})),
        throwsFormatException,
      );
    });
  });

  group('Lizenz', () {
    test('die Attribution lautet genau so, wie RepDB sie verlangt', () {
      expect(repdbAttribution, 'Exercise data by RepDB (repdb.co)');
    });

    test('Skript und App führen dieselbe Zeichenkette', () {
      final skript = File('../scripts/exercises-convert.mjs')
          .readAsStringSync();
      expect(skript, contains("ATTRIBUTION = '$repdbAttribution'"));
    });

    test('jedes Bild trägt die Attribution mit sich', () {
      final bilder = Uebungsbilder.parse(
        File('assets/exercises/exercises.json').readAsStringSync(),
      );
      for (final id in bilder.exerciseIds) {
        expect(bilder.fuer(id)!.attribution, repdbAttribution);
      }
    });
  });
}

extension on List<String> {
  void swap(int a, int b) {
    final t = this[a];
    this[a] = this[b];
    this[b] = t;
  }
}
