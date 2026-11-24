import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:repit/design/formatierung.dart';

/// Tests für `Format.standZeitpunkt` — den Zeitstempel der Stand-Zeile
/// (#200), geschrieben gegen
/// `docs/superpowers/specs/2026-11-03-healthkit-test-aufteilung.md`,
/// Abschnitt 5.
///
/// **Warum es `zuletztAktualisiert` nicht tut:** Das hängt „· vor 3
/// Minuten" an und ist für die Aktualitätszeile der alten Swift-App
/// gebaut. Die Stand-Zeile sagt nur, *wann* gelesen wurde — der Abstand
/// dazu ist eine zweite Angabe, die die Zeile zweizeilig werden ließe.
///
/// ## Der Tagesvergleich läuft über die rohen Kalenderfelder
///
/// Nicht über `kalendertag(…)`/`BerlinCalendar.dayKey`, und das ist eine
/// Entscheidung, keine Nachlässigkeit. `Format.uhrzeit` formatiert die
/// **Felder** eines `DateTime` (`DateFormat` rechnet keine Zeitzone um),
/// `dayKey` dagegen deutet denselben Wert als **Instant** und rechnet
/// ihn nach Berlin. Wer beides in einer Funktion mischt, bekommt eine
/// Uhrzeit aus der einen und einen Tag aus der anderen Lesart — bei
/// einem Stand um 23:30 stünde dann „gestern 23:30" neben einer Uhrzeit,
/// die zu diesem „gestern" nicht gehört.
///
/// In der App ist der Stand ein lokaler Zeitpunkt (`clockProvider` ist
/// `DateTime.now()`), also stimmen Feldlesart und Ortszeit überein. Der
/// Rest von `Format` hält es genauso (`_selberTag` in
/// `zuletztAktualisiert`) — eine zweite Lesart im selben Baukasten wäre
/// der eigentliche Fehler.
///
/// **Was hier nicht geprüft wird:** der genaue Wortlaut jenseits der
/// drei Fälle. Dass „gestern" kleingeschrieben ist und das Komma hinter
/// dem Datum steht, ist eine Setzung des Entwurfs, keine Anforderung —
/// aber die drei *Fälle* sind eine: Ein Stand von gestern muss als
/// solcher erkennbar sein, sonst sieht er am Morgen nach heute Abend
/// aus, nach einem Zeitpunkt, der noch gar nicht war.
void main() {
  setUpAll(() => initializeDateFormatting('de_DE'));

  final jetzt = DateTime.utc(2026, 11, 3, 15, 31);

  test('ein Stand vom selben Kalendertag nennt nur die Uhrzeit', () {
    expect(
      Format.standZeitpunkt(DateTime.utc(2026, 11, 3, 7, 12), jetzt: jetzt),
      '07:12',
    );
  });

  test('ein Stand von gestern heisst "gestern"', () {
    expect(
      Format.standZeitpunkt(DateTime.utc(2026, 11, 2, 21, 58), jetzt: jetzt),
      'gestern 21:58',
    );
  });

  test('aelter als gestern nennt das Datum', () {
    expect(
      Format.standZeitpunkt(DateTime.utc(2026, 10, 27, 21, 58), jetzt: jetzt),
      '27.10., 21:58',
    );
  });

  /// Der Fall, der #200 ausgelöst hat: Nach einem Lauf um 21:58 steht am
  /// Morgen danach eine Uhrzeit da, die an diesem Tag noch gar nicht
  /// war. Ohne das Wort „gestern" liest sich das als heute Abend.
  test('kurz nach Mitternacht ist der Abendstand von gestern', () {
    final text = Format.standZeitpunkt(
      DateTime.utc(2026, 11, 2, 21, 58),
      jetzt: DateTime.utc(2026, 11, 3, 6, 10),
    );

    expect(text, contains('gestern'));
    expect(text, contains('21:58'));
  });

  /// „Gestern" heißt der Kalendertag davor, nicht „vor weniger als 24
  /// Stunden". Ein Stand von 23:50 ist um 00:10 keine zwanzig Minuten
  /// alt und trotzdem von gestern — wer nach Dauer rechnet, nennt ihn
  /// „heute" und behauptet damit einen Zeitpunkt, der noch bevorsteht.
  test('"gestern" meint den Kalendertag, nicht 24 Stunden', () {
    expect(
      Format.standZeitpunkt(
        DateTime.utc(2026, 11, 2, 23, 50),
        jetzt: DateTime.utc(2026, 11, 3, 0, 10),
      ),
      'gestern 23:50',
    );
  });

  /// Über die Monatsgrenze hinweg ist der 31.10. der Vortag des 01.11.,
  /// nicht „älter". Ein Vergleich, der nur `day - 1` rechnet, fällt hier
  /// durch.
  test('"gestern" traegt ueber die Monatsgrenze', () {
    expect(
      Format.standZeitpunkt(
        DateTime.utc(2026, 10, 31, 22, 5),
        jetzt: DateTime.utc(2026, 11, 1, 9, 0),
      ),
      'gestern 22:05',
    );
  });

  /// Ein Stand, der in der Zukunft liegt, ist kein erwarteter Zustand —
  /// aber er darf nicht „gestern" heißen. Geprüft wird nur das: nicht
  /// falsch, der Wortlaut ist offen.
  test('ein Stand aus der Zukunft heisst nicht "gestern"', () {
    expect(
      Format.standZeitpunkt(
        DateTime.utc(2026, 11, 4, 9, 0),
        jetzt: DateTime.utc(2026, 11, 3, 9, 0),
      ),
      isNot(contains('gestern')),
    );
  });

  /// Eine Zeile, die mal ein-, mal zweizeilig ist, verschiebt alles
  /// darunter — genau der Sprung, den die Regel „Eine Anzeige, die es
  /// gibt, hat genau eine Form" verhindern soll.
  test('traegt nie einen Zeilenumbruch', () {
    for (final stand in [
      DateTime.utc(2026, 11, 3, 7, 12),
      DateTime.utc(2026, 11, 2, 21, 58),
      DateTime.utc(2026, 10, 27, 21, 58),
    ]) {
      expect(Format.standZeitpunkt(stand, jetzt: jetzt), isNot(contains('\n')));
    }
  });
}
