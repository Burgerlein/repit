// Belege und Ende je Tag (#454 unter #375): `tagesbelegeProvider` und
// `tagesendeProvider`.
//
// API und Vertrag sind durch `app/test/tag/tagesbelege_test.dart`
// verbindlich vorgegeben (siehe dessen Dateikopf, dort auch, welche Punkte
// der Test-Agent festgelegt hat) — diese Datei darf die Tests ausführen,
// aber nicht verändern (`CLAUDE.md`). Spec:
// `docs/superpowers/specs/2026-11-10-tagesgrenze-design.md`, Abschnitt
// „Belege und Ende je Tag", dazu V12 und V13.
//
// **Kein `Messwert<T>` und kein Cache (V12).** Die Belege sind die Eingabe
// einer Rechnung, keine Anzeige aus Apple Health: Scheitert Health, zählen
// die eigenen Belege allein, und ein Fehlerzustand entsteht nicht. Gelesen
// wird je Tag einmal; weil beide Familien `autoDispose` sind, liest jedes
// Öffnen des Blatts neu, und beim Blättern sammeln sich keine Abfragen.
//
// Welcher Tag läuft und wann ein Tag endete, rechnet der Kern
// (`laufenderTag`, `tagesende`). Diese Datei sammelt nur die Eingaben.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../core/messwert.dart';
import '../data/wach_belege.dart';
import '../health/health_provider.dart';
import '../health/health_types.dart';
import 'tagesgrenze_eingaben.dart';

/// Das Fenster, in dem Belege für den Tag [tag] zählen: [tag] 04:00 bis
/// Folgetag 08:00, beide von der Berliner Wanduhr (V12). Über die
/// Zeitumstellung ist es eine Stunde länger oder kürzer, nie verschoben.
({DateTime von, DateTime bis}) _fenster(String tag) => (
  von: wanduhrZeitpunkt(tag, Mahlzeitfenster.tagesbeginnInMinuten),
  bis: wanduhrZeitpunkt(_folgetag(tag), tagesObergrenzeInMinuten),
);

/// Der Kalendertag nach [tag], als ISO-Tag.
String _folgetag(String tag) =>
    BerlinCalendar.dayKey(BerlinCalendar.addDays(wanduhrZeitpunkt(tag, 0), 1));

/// Die Wachbelege eines Tages D (ISO-Tag als Familienargument): eigene
/// Belege aus der Tabelle, Schritte und Trainings aus Health, im Fenster
/// D 04:00 bis D+1 08:00, **höchstens bis jetzt** (V12). Die Reihenfolge
/// ist nicht zugesagt; die Kern-Rechnungen sortieren selbst.
final tagesbelegeProvider = AsyncNotifierProvider.autoDispose
    .family<TagesbelegeNotifier, List<Wachbeleg>, String>(
      TagesbelegeNotifier.new,
    );

class TagesbelegeNotifier extends AsyncNotifier<List<Wachbeleg>> {
  TagesbelegeNotifier(this.tag);

  /// Der Tag D als ISO-Tag.
  final String tag;

  @override
  Future<List<Wachbeleg>> build() async {
    final repo = ref.watch(wachbelegRepositoryProvider);
    final quelle = ref.watch(healthProvider);
    // Wie bei `DailyMetricsNotifier` begründet (#176): Ein Lauf vor der
    // beantworteten Freigabe kam leer zurück, ohne Fehler. Danach wird neu
    // gelesen, statt auf dem leeren Ergebnis stehen zu bleiben.
    ref.watch(freigabeProvider);
    final jetzt = ref.watch(clockProvider)().toUtc();

    final fenster = _fenster(tag);
    final von = fenster.von;
    final bis = fenster.bis.isAfter(jetzt) ? jetzt : fenster.bis;
    // Ein Tag, der noch nicht begonnen hat, hat keine Belege. Health wird
    // dann gar nicht erst mit einem verkehrten Fenster gefragt.
    if (bis.isBefore(von)) return const [];

    // Alle drei angestoßen, bevor auf einen gewartet wird.
    final eigene = repo.zwischen(von, bis);
    final schritte = _ohneFehler(() => quelle.hourlySteps(von, bis));
    final trainings = _ohneFehler(() => quelle.workouts(von, bis));

    bool imFenster(Wachbeleg b) => !b.von.isBefore(von) && !b.von.isAfter(bis);
    return [
      ...await eigene,
      ...belegeAusSchritten(await schritte).where(imFenster),
      ...belegeAusTrainings(await trainings).where(imFenster),
    ];
  }

  /// Eine Health-Abfrage, die bei einem Fehler leer ausgeht (V12): Die
  /// eigenen Belege zählen dann allein. Gefangen wird je Art, damit ein
  /// gescheitertes Lesen der Schritte die Trainings nicht mitnimmt.
  static Future<List<T>> _ohneFehler<T>(
    Future<List<T>> Function() frage,
  ) async {
    try {
      return await frage();
    } on Object {
      return const [];
    }
  }
}

/// Wann der Tag D (ISO-Tag als Familienargument) endete — `tagesende` aus
/// dem Kern mit den Belegen aus [tagesbelegeProvider] und der Nacht, deren
/// Aufwachtag D+1 ist (aus [sleepProvider], nie über den Kanal direkt).
///
/// `null`:
/// - solange die Belege noch nicht gelesen sind;
/// - solange die Nächte noch nicht gelesen sind ([NochNie], oder ein Wert
///   aus dem Cache, der die Nacht von D+1 nicht enthält, während Health
///   noch nachliest — ein Ende auf 04:00, das gleich darauf auf 00:47
///   springt, behauptete etwas, das nicht feststand);
/// - für den laufenden Tag und jeden späteren. Welcher Tag läuft, rechnet
///   `laufenderTag` aus dem Kern mit denselben Belegen und Nächten und der
///   Uhr zum Zeitpunkt der Rechnung. Neu gerechnet wird, wenn sich Belege
///   oder Nächte ändern, nicht mit dem Fortschreiten der Uhr.
///
/// [LeerNachLauf] und [Fehlgeschlagen] bei den Nächten zählen als gelesen,
/// ohne Nacht — wie bei den Belegen (V12) rechnet die Grenze dann mit dem,
/// was da ist.
final tagesendeProvider = Provider.autoDispose.family<Tagesende?, String>((
  ref,
  tag,
) {
  final belege = ref.watch(tagesbelegeProvider(tag)).value;
  final schlaf = ref.watch(sleepProvider).value;
  final jetzt = ref.watch(clockProvider)();
  if (belege == null || schlaf == null) return null;

  final folgetag = _folgetag(tag);
  final naechte = _gelesen(schlaf, folgetag);
  if (naechte == null) return null;

  final gemeldet = [
    for (final n in naechte)
      if (nachtAus(n) case final g?) (aufwachtag: _aufwachtag(n), nacht: g),
  ];

  final laufend = laufenderTag(
    jetzt: jetzt,
    belege: belege,
    naechte: gemeldet.map((g) => g.nacht),
  );
  if (tag.compareTo(laufend.tag) >= 0) return null;

  GemeldeteNacht? nacht;
  for (final g in gemeldet) {
    if (g.aufwachtag == folgetag) {
      nacht = g.nacht;
      break;
    }
  }
  return tagesende(tag: tag, belege: belege, nacht: nacht);
});

/// Der Tag, zu dem die Nacht [n] zählt: der Tag des Aufwachens.
String _aufwachtag(SleepNight n) => BerlinCalendar.dayKey(n.date);

/// Die Nächte aus [schlaf], sobald sie für den Tag mit Aufwachtag
/// [folgetag] als gelesen gelten; sonst `null`. Siehe [tagesendeProvider].
List<SleepNight>? _gelesen(
  Messwert<List<SleepNight>> schlaf,
  String folgetag,
) => switch (schlaf) {
  NochNie() => null,
  Bekannt(:final wert, :final laeuft) =>
    !laeuft || wert.any((n) => _aufwachtag(n) == folgetag) ? wert : null,
  LeerNachLauf() || Fehlgeschlagen() => const [],
};
