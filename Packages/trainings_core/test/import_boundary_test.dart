import 'dart:io';

import 'package:test/test.dart';

/// Löst die Behauptung der Architektur ein: `trainings_core` importiert und
/// exportiert ausschließlich `dart:core` und `dart:math` — kein Flutter,
/// kein drift, kein Platform-Channel. Ein Paket allein erzwingt das nicht,
/// dieser Test schon. Die Dart-Entsprechung zu `ImportBoundaryTests` im
/// Swift-Paket `Packages/TrainingsCore`.
///
/// Paketinterne Importe und Exporte sind erlaubt — sonst könnte eine Datei
/// nicht einmal eine andere Datei desselben Pakets importieren, und
/// `lib/trainings_core.dart` könnte kein Barrel-File sein: relative Pfade
/// innerhalb von `lib/` und `package:trainings_core/…` zählen nicht als
/// Verstoß. Jeder andere `dart:`-Import/-Export und jeder
/// `package:`-Import/-Export auf ein fremdes Paket zählt.
///
/// Geprüft werden `import` **und** `export` nach denselben Regeln — in Dart
/// ist `export 'package:irgendein_fremdes_paket/…dart';` ohne begleitenden
/// `import` zulässig und würde eine reine Import-Prüfung lautlos umgehen.
/// Eine Anweisung wird als zusammenhängender Text von `import`/`export` bis
/// zum abschließenden Semikolon gelesen, nicht zeilenweise — sonst entgehen
/// bedingte Importe wie
/// `import 'a.dart' if (dart.library.io) 'b.dart';`, deren zweite URI auf
/// einer Folgezeile stehen kann. `part`/`part of` brauchen keine eigene
/// Prüfung: Dart lässt für `part`-Direktiven nur relative URIs zu, ein
/// fremdes Paket ließe sich darüber nicht einschleusen — und jede
/// `.dart`-Datei in `lib/`, auch eine `part`-Datei, wird ohnehin einzeln
/// gescannt.
///
/// Block- **und** Zeilenkommentare werden vor dem Suchen entfernt, und zwar
/// in dieser Reihenfolge: zuerst `/* … */` über den ganzen Dateitext hinweg
/// (ein `//` innerhalb eines Blockkommentars soll nicht versehentlich als
/// Zeilenkommentar-Grenze wirken), danach `//` je Zeile. Ohne das meldet der
/// zeilenungebundene Anweisungs-Regex (nötig für mehrzeilige/bedingte
/// Importe) auch Beispielcode in einem Dartdoc-Kommentar wie
/// `/** import 'package:verboten/foo.dart'; */` als Verstoß — ein falscher
/// Alarm, der genau dann zuschlägt, wenn `lib/trainings_core.dart` zum
/// dokumentierten Barrel-File wird.
List<String> _verstoesseInQuelltext(String pfad, String quelltext) {
  const erlaubteDartUris = {'dart:core', 'dart:math'};
  const eigenesPaket = 'trainings_core';
  final verstoesse = <String>[];

  final anweisung = RegExp(r'\b(import|export)\s+(.*?);', dotAll: true);
  final uri = RegExp(r"""['"]([^'"]+)['"]""");

  // Nicht-gierig (`.*?`): endet am ersten `*/`. Dart erlaubt geschachtelte
  // Blockkommentare (`/* außen /* innen */ immer noch außen */`), bei denen
  // das zu früh wäre — korrekt ginge das nur mit einem zustandsbehafteten
  // Scanner statt einem regulären Ausdruck. Für einen Wächter dieser Größe
  // ist das bewusst in Kauf genommen, nicht übersehen.
  final ohneBlockkommentare = quelltext.replaceAll(
    RegExp(r'/\*.*?\*/', dotAll: true),
    '',
  );
  final ohneKommentare = ohneBlockkommentare
      .split('\n')
      .map((zeile) {
        final index = zeile.indexOf('//');
        return index >= 0 ? zeile.substring(0, index) : zeile;
      })
      .join('\n');

  for (final treffer in anweisung.allMatches(ohneKommentare)) {
    final art = treffer.group(1)!; // "import" oder "export"
    final rumpf = treffer.group(2)!;

    // Eine Anweisung kann mehr als eine URI tragen — ein bedingter Import
    // (`import 'a.dart' if (dart.library.io) 'b.dart';`) nennt mehrere.
    // Jede einzelne zählt für sich.
    for (final uriTreffer in uri.allMatches(rumpf)) {
      final ziel = uriTreffer.group(1)!;

      final bool erlaubt;
      if (ziel.startsWith('dart:')) {
        erlaubt = erlaubteDartUris.contains(ziel);
      } else if (ziel.startsWith('package:')) {
        erlaubt = ziel.startsWith('package:$eigenesPaket/');
      } else {
        erlaubt = true; // relativer, paketinterner Pfad
      }

      if (!erlaubt) {
        verstoesse.add('$pfad: $art $ziel');
      }
    }
  }

  return verstoesse;
}

void main() {
  test('trainings_core importiert und exportiert nur dart:core, dart:math '
      'und sich selbst', () {
    final lib = Directory('lib');
    if (!lib.existsSync()) {
      // Leeres Paket, keine Quelldateien — nichts zu beanstanden.
      return;
    }

    final verstoesse = <String>[];
    for (final datei in lib.listSync(recursive: true).whereType<File>()) {
      if (!datei.path.endsWith('.dart')) continue;
      verstoesse.addAll(
        _verstoesseInQuelltext(datei.path, datei.readAsStringSync()),
      );
    }

    expect(
      verstoesse,
      isEmpty,
      reason:
          'trainings_core darf nur dart:core, dart:math und sich '
          'selbst importieren oder exportieren',
    );
  });

  test('ein verbotener Import in einem Blockkommentar ist kein Verstoß', () {
    const quelltext = '''
/**
 * Beispiel: import 'package:verboten/foo.dart';
 */
int zwei() => 2;
''';

    expect(_verstoesseInQuelltext('beispiel.dart', quelltext), isEmpty);
  });

  test('ein echter verbotener Import schlägt weiter an, auch neben einem '
      'harmlosen Blockkommentar', () {
    const quelltext = '''
/**
 * Beispiel: import 'package:verboten/foo.dart';
 */
import 'package:tatsaechlich_verboten/bar.dart';
''';

    expect(_verstoesseInQuelltext('beispiel.dart', quelltext), [
      'beispiel.dart: import package:tatsaechlich_verboten/bar.dart',
    ]);
  });
}
