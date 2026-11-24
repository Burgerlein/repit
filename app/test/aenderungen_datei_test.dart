// Wächtertest auf die ECHTE Datei `app/assets/aenderungen.json` (#89,
// Prüffall 5 der Spec `2026-11-19-aenderungsblatt-design.md`).
//
// Die Spec: Eine leere oder kaputte Datei ist ein Programmierfehler, kein
// Laufzeitfall — das Blatt hat deshalb genau einen Zustand und keinen
// Leerzustand, und DIESER Test ist die Stelle, die das vor jedem Build
// durchsetzt. Er prüft: Die Datei liegt im Bundle-Pfad, sie parst, sie hat
// mindestens eine Fassung, jede Fassung mindestens einen Eintrag, und jedes
// `ziel` steht in der Zuordnungstabelle (`zielZuAppTarget` liefert
// nicht-null). Ob die *Inhalte* ehrlich sind, erzwingt er bewusst nicht —
// das bleibt Disziplin, wie beim Entwurfsboard (Spec, „Die Pflege-Regel").
//
// Gelesen wird über `dart:io` relativ zum Paket (`flutter test` läuft mit
// Arbeitsverzeichnis `app/`), nicht über `rootBundle`: Der Test prüft die
// Datei im Repository, bevor sie ein Bundle wird.
//
// **Ein Wächtertest ist von Anfang an grün gedacht** (CLAUDE.md) — rot ist
// er nur, solange Datei oder Tabelle fehlen, und genau das soll er melden.
//
// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
// Diese Datei darf ausgeführt, aber nicht verändert werden.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:repit/shell/aenderungen.dart'
    show zielZuAppTarget;

void main() {
  const pfad = 'assets/aenderungen.json';

  /// Liest und parst die echte Datei — jeder Fall unten geht durch diese
  /// eine Stelle, damit „Datei fehlt" und „Datei parst nicht" als eigene,
  /// klare Meldungen auftauchen statt als Folgefehler.
  List<dynamic> ladeFassungen() {
    final datei = File(pfad);
    expect(
      datei.existsSync(),
      isTrue,
      reason:
          '$pfad fehlt. Die Datei ist die eine Quelle der Fassungsnamen '
          'und wird im selben Commit wie das Feature gepflegt (Spec #89).',
    );

    final Object? geparst;
    try {
      geparst = jsonDecode(datei.readAsStringSync());
    } on FormatException catch (fehler) {
      fail('$pfad ist kein gültiges JSON: $fehler');
    }

    expect(
      geparst,
      isA<List<dynamic>>(),
      reason:
          '$pfad muss auf oberster Ebene eine Liste von Fassungen sein '
          '(Spec #89, Abschnitt „Die Datei").',
    );
    return geparst! as List<dynamic>;
  }

  test('die Datei existiert, parst und hat mindestens eine Fassung', () {
    final fassungen = ladeFassungen();

    expect(
      fassungen,
      isNotEmpty,
      reason:
          'Mindestens eine Fassung: Die Mehr-Fußzeile liest den '
          'Fassungsnamen aus dem ersten Eintrag — eine leere Liste ließe '
          'sie ins Leere greifen.',
    );
  });

  test('jede Fassung hat einen Namen und mindestens einen Eintrag', () {
    final fassungen = ladeFassungen();

    for (final (i, fassung) in fassungen.indexed) {
      expect(
        fassung,
        isA<Map<String, dynamic>>(),
        reason: 'Fassung an Position $i ist kein Objekt.',
      );
      final map = fassung as Map<String, dynamic>;

      expect(
        map['fassung'],
        isA<String>(),
        reason: 'Fassung an Position $i: "fassung" fehlt oder ist kein Text.',
      );
      expect(
        (map['fassung'] as String).trim(),
        isNotEmpty,
        reason: 'Fassung an Position $i: "fassung" ist leer.',
      );

      final stand = map['stand'];
      if (stand != null) {
        expect(
          stand,
          isA<String>(),
          reason: 'Fassung "${map['fassung']}": "stand" ist kein Text.',
        );
        expect(
          RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(stand as String),
          isTrue,
          reason:
              'Fassung "${map['fassung']}": "stand" ($stand) ist kein '
              'ISO-Tagesstring (JJJJ-MM-TT) — der Datumsschlüssel des '
              'Projekts (CLAUDE.md).',
        );
      }

      expect(
        map['eintraege'],
        isA<List<dynamic>>(),
        reason:
            'Fassung "${map['fassung']}": "eintraege" fehlt oder ist '
            'keine Liste.',
      );
      expect(
        map['eintraege'] as List<dynamic>,
        isNotEmpty,
        reason:
            'Fassung "${map['fassung']}" hat keinen Eintrag — eine '
            'Änderungsliste ohne Eintrag zur Fassung ist schlechter als '
            'keine (Spec #89, „Die Pflege-Regel").',
      );
    }
  });

  test('jeder Eintrag hat Titel und Satz', () {
    final fassungen = ladeFassungen();

    for (final fassung in fassungen.whereType<Map<String, dynamic>>()) {
      final eintraege = fassung['eintraege'];
      if (eintraege is! List<dynamic>) continue; // meldet der Fall oben
      for (final (i, eintrag) in eintraege.indexed) {
        final wo = 'Fassung "${fassung['fassung']}", Eintrag $i';
        expect(eintrag, isA<Map<String, dynamic>>(), reason: '$wo: kein Objekt.');
        final map = eintrag as Map<String, dynamic>;

        for (final feld in ['titel', 'text']) {
          expect(
            map[feld],
            isA<String>(),
            reason: '$wo: "$feld" fehlt oder ist kein Text.',
          );
          expect(
            (map[feld] as String).trim(),
            isNotEmpty,
            reason: '$wo: "$feld" ist leer.',
          );
        }
      }
    }
  });

  test('jedes ziel steht in der Zuordnungstabelle', () {
    final fassungen = ladeFassungen();

    for (final fassung in fassungen.whereType<Map<String, dynamic>>()) {
      final eintraege = fassung['eintraege'];
      if (eintraege is! List<dynamic>) continue; // meldet der Fall oben
      for (final eintrag in eintraege.whereType<Map<String, dynamic>>()) {
        final ziel = eintrag['ziel'];
        if (ziel == null) continue; // ziel ist optional — reine Anzeige

        expect(
          ziel,
          isA<String>(),
          reason:
              'Fassung "${fassung['fassung']}", Eintrag '
              '"${eintrag['titel']}": "ziel" ist kein Text.',
        );
        expect(
          zielZuAppTarget(ziel as String),
          isNotNull,
          reason:
              'Fassung "${fassung['fassung']}", Eintrag '
              '"${eintrag['titel']}": ziel "$ziel" steht nicht in der '
              'Zuordnungstabelle (zielZuAppTarget) — ein unbekanntes ziel '
              'ist ein Programmierfehler, kein Laufzeitfall (Spec #89).',
        );
      }
    }
  });
}
