import 'dart:convert';
import 'dart:typed_data';

/// Bausteine für **erfundene** Exportdateien (`trainingsexport`, Fassung 2)
/// in den Tests zur Übernahme (#59 Teil 1, mit #482).
///
/// Grundlage ist `docs/superpowers/specs/2026-11-11-gym-uebernahme-design.md`,
/// Abschnitt 2, und `AppExport.swift`. **Wer Tests schreibt, schreibt nicht
/// die Implementierung** (`CLAUDE.md`): Diese Datei darf benutzt, aber nicht
/// verändert werden.
///
/// **Alle Namen, Zahlen und Zeitpunkte sind erfunden** und liegen im Jahr
/// 2099 — keine echten Gesundheits- oder Trainingsdaten, kein reales Datum.
/// Im Januar gilt Berliner Winterzeit (UTC+1): `2099-01-14T09:00:00Z` ist
/// 10:00 Berliner Zeit am 14.01.2099, `2099-01-13T23:00:00Z` ist der
/// Berliner Tagesbeginn des 14.01.

/// `2099-01-<tag>T<stunde>:00:00Z` als Zeichenkette, wie Swift sie schreibt.
String zeit(int tag, [int stunde = 9, int minute = 0]) =>
    '2099-01-${tag.toString().padLeft(2, '0')}T'
    '${stunde.toString().padLeft(2, '0')}:'
    '${minute.toString().padLeft(2, '0')}:00Z';

/// Ein Satz, so wie er in der Datei steht.
Map<String, Object?> rohSatz(num gewicht, int wdh) => {
  'weight': gewicht,
  'reps': wdh,
};

Map<String, Object?> rohUebung(String id, List<Map<String, Object?>> saetze) =>
    {'exerciseID': id, 'sets': saetze};

/// Zwei Sätze Bankdrücken: 60 × 10 und 62,5 × 8.
Map<String, Object?> rohBank() =>
    rohUebung('benchPress', [rohSatz(60, 10), rohSatz(62.5, 8)]);

/// Eine Sitzung. **Felder ohne Wert fehlen** — so schreibt Swift `nil`.
Map<String, Object?> rohSitzung({
  required String id,
  required String datum,
  String? workout,
  int? minuten,
  String? notiz,
  List<Object?>? uebungen,
}) => {
  'id': id,
  'date': datum,
  if (workout != null) 'workout': workout,
  if (minuten != null) 'minutes': minuten,
  if (notiz != null) 'note': notiz,
  'exercises': uebungen ?? [rohBank()],
};

/// Die ganze Hülle. [stand] ersetzt den Block `app` im Ganzen,
/// [sitzungen] füllt nur `app.sessions`; die fünf anderen Stände bleiben
/// leer, wenn sie nicht in [uebrige] stehen.
Map<String, Object?> exportDatei({
  List<Object?> sitzungen = const [],
  Map<String, Object?> uebrige = const {},
  Object? format = 'trainingsexport',
  Object? version = 2,
  String zone = 'Europe/Berlin',
  String erzeugt = '2099-02-01T08:30:00Z',
  Map<String, Object?>? stand,
}) => {
  'format': format,
  'version': version,
  'generated': erzeugt,
  'timezone': zone,
  'app':
      stand ??
      {
        'sessions': sitzungen,
        'circumferences': <Object?>[],
        'swaps': <Object?>[],
        'drafts': <Object?>[],
        'dataWindow': <Object?>[],
        'dashboardImport': <Object?>[],
        ...uebrige,
      },
};

/// Die Datei als Bytes, wie der Dateiwähler sie liefert.
Uint8List alsBytes(Object? json) =>
    Uint8List.fromList(utf8.encode(jsonEncode(json)));

/// Eine Datei der Fassung 1 — die Gestalt steht in `AppExportTests.swift`.
Map<String, Object?> fassungEins() => {
  'format': 'trainingsexport',
  'version': 1,
  'generated': '2099-03-01T09:15:00Z',
  'timezone': 'Europe/Berlin',
  'from': '2099-02-28',
  'to': '2099-03-01',
  'days': <Object?>[],
  'meals': <Object?>[],
  'workouts': <Object?>[],
  'sleep': <Object?>[],
};
