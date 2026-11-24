import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repit/design/symbole.dart';

/// Test für die Zuordnungstabelle in `symbole.dart` (Task 9).
///
/// Geprüft wird die **Tabelle**, nicht die Glyphen: Welches Icon-Paket
/// (Lucide oder Phosphor) die Namen am Ende zeichnet, steht laut
/// `docs/superpowers/specs/2026-10-23-flutter-rebuild-design.md` Abschnitt
/// 12 noch nicht fest — das ist eine Entscheidung fürs Board, keine für
/// diesen Test. Fix ist nur, dass jeder der rund 20 tatsächlich benutzten
/// Namen aus `Sources/Features/Shell/RootView.swift:29-40` und
/// `Sources/Features/Shell/MoreView.swift:51-67` einen Eintrag bekommt und
/// keiner stillschweigend auf ein gemeinsames Platzhalter-Symbol
/// zurückfällt. SF Symbols sind laut Brief ausgeschlossen (Apple lizenziert
/// sie für Android nicht) — hier wird ohnehin nur gegen `IconData` geprüft,
/// nicht gegen einen bestimmten Namensraum.
///
/// **Entscheidung, nicht mit Tim abgestimmt:** Der Brief legt keine
/// Datenform für die Tabelle fest. Dieser Test nimmt `Symbole.tabelle` als
/// `Map<String, IconData>` an — `IconData`, weil sowohl Lucide als auch
/// Phosphor dafür Konstanten liefern und die Wahl zwischen beiden hier nicht
/// vorweggenommen werden soll. Passt das nicht zur gewählten Form, bitte
/// melden statt den Test umzuschreiben.
void main() {
  // Eins zu eins aus den beiden genannten Dateien übernommen, dedupliziert
  // (z. B. taucht "figure.run" in MoreView.swift für zwei verschiedene
  // Zeilen auf — hier zählt der Name einmal).
  const benutzteNamen = <String>{
    // RootView.swift:29-40 — Tab-Leiste
    'calendar',
    'list.bullet',
    'dumbbell',
    'dumbbell.fill',
    'fork.knife',
    'ellipsis',
    // MoreView.swift:51-67 — Mehr-Menü
    'target',
    'figure.run',
    'figure.arms.open',
    'moon.zzz',
    'bed.double',
    'sun.max',
    'waveform.path.ecg',
    'chart.xyaxis.line',
    'heart',
    'checkmark.seal',
    'gearshape',
    'square.and.arrow.down',
    'stethoscope',
    'square.and.arrow.up',
  };

  test('die Namensliste selbst hat die rund 20 erwarteten Eintraege', () {
    // Prüft die Testdaten gegen sich selbst ab, falls beim Abtippen aus den
    // Swift-Dateien ein Name verloren oder doppelt gezählt wurde.
    expect(benutzteNamen, hasLength(20));
  });

  test('kennt jeden benutzten Namen', () {
    for (final name in benutzteNamen) {
      expect(
        Symbole.tabelle.containsKey(name),
        isTrue,
        reason: '"$name" fehlt in Symbole.tabelle',
      );
    }
  });

  test(
    'keine zwei dieser Namen fallen heimlich auf dasselbe Symbol zurueck',
    () {
      // Indiz, kein Beweis (siehe Bericht): Ein einzelnes Platzhalter-Symbol,
      // das für mehrere fehlende Einträge einspringt, erzeugt doppelte Werte.
      // In der Vorlage steht jeder der 20 Namen für ein eigenes Icon, ein
      // Duplikat hier wäre also ein Hinweis auf einen stillen Rückfall, nicht
      // auf Absicht.
      final werte = [
        for (final name in benutzteNamen)
          if (Symbole.tabelle.containsKey(name)) Symbole.tabelle[name],
      ];

      expect(werte.toSet(), hasLength(werte.length));
    },
  );
}
