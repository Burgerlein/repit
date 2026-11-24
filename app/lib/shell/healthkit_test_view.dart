import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/messwert.dart';
import '../design/formatierung.dart';
import '../design/glas_abstand.dart';
import '../design/grosse_ueberschrift.dart';
import '../design/hinweisfuss.dart';
import '../design/icon_row.dart';
import '../design/inset_card.dart';
import '../design/palette.dart';
import '../design/platzhalter.dart';
import '../design/section_header.dart';
import '../design/stand_zeile.dart';
import '../health/health_provider.dart';
import '../health/health_types.dart';
import 'heute_view.dart' show heuteZustandAusProvider;
import 'mess_abschnitte.dart' show datumZumAnzeigen;

/// Der HealthKit-Test-Schirm — Entwurf `docs/screens/screens/healthtest.js`
/// (siehe dessen Kommentarkopf: „kein Schirm für den Alltag, sondern einer
/// für die Frage 'liegt es an der App oder an den Daten'"). Auftrag: #45
/// („Der HealthKit-Test soll zeigen, was wir lesen *und nutzen*").
///
/// **Umgebaut am 03.11.2026 (#262)** nach der Spec
/// `docs/superpowers/specs/2026-11-03-healthkit-test-aufteilung.md` und
/// dem am selben Tag freigegebenen Entwurf (#256). Vorher kippte dieser
/// Schirm alle dreizehn Felder aus `DailyMetrics` in **eine** Gruppe
/// „Tageswerte, roh" — dreizehn gleich aussehende Zeilen am Stück
/// beantworten aber genau die Frage nicht, für die es ihn gibt. Die
/// Gruppen trennen jetzt nach **Herkunft**: was täglich entsteht, was bei
/// einer Wägung entsteht, was die App selbst rechnet.
///
/// API und Verhalten sind durch `test/shell/healthkit_test_view_test.dart`
/// und `test/shell/healthkit_test_aufteilung_test.dart` verbindlich
/// vorgegeben — diese Datei darf die Tests ausführen, aber nicht
/// verändern (`CLAUDE.md`, „Wer Tests schreibt, schreibt nicht die
/// Implementierung").
///
/// **Zeigt nur, was `dailyMetricsProvider` liefert.** Workouts, Ernährung
/// und Schlaf stehen als Gruppen da, aber leer: Dafür gibt es noch keinen
/// Provider (`health_provider.dart`s eigener Dateikopf begründet das), die
/// Lücke liegt als #123. Tims Entscheidung vom 03.11.2026 war, sie
/// trotzdem zu zeigen — ein Schirm, der eine Gruppe weglässt, sieht aus
/// wie einer, der sie nicht kann.
///
/// Bringt **keinen** eigenen `CupertinoPageScaffold`/keine `NavigationBar`
/// mit (Hausregel, parallel zu `HeuteView`/`PlatzhalterTab`) — der
/// Gastgeber (`MehrView._oeffneHealthKitTest`) stellt beides.
class HealthKitTestView extends ConsumerWidget {
  const HealthKitTestView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Der Berechtigungsdialog wird höchstens einmal pro Installation
    // ausgelöst; `freigabeAnfrageProvider` liegt seit #176 in
    // `health_provider.dart` und wird von den Lade-Providern selbst
    // beobachtet.
    ref.watch(freigabeAnfrageProvider);

    final zustand = heuteZustandAusProvider(ref.watch(dailyMetricsProvider));
    final jetzt = ref.watch(clockProvider)();

    // `CustomScrollView` statt `SingleChildScrollView`: Nur ein Sliver-
    // Baum kann `CupertinoSliverRefreshControl` tragen, und das ist die
    // einzige Art, die Läufe neu anzustoßen, die dieser Schirm bekommt
    // (Tims Entscheidung vom 03.11.2026 gegen einen sichtbaren Knopf —
    // der bleibt als #228 offen).
    //
    // Der Inhalt sitzt weiterhin in **einem** Sliver statt in einer
    // Liste: Ein Widget-Test, der den ganzen Baum durchsucht, soll jede
    // Zeile finden, nicht nur die im sichtbaren Ausschnitt.
    return CustomScrollView(
      slivers: [
        CupertinoSliverRefreshControl(
          onRefresh: () async {
            // **Dieselben drei wie früher der Knopf „Neu laden"** (#228).
            // Die Geste hat ihn abgelöst, nicht seinen Umfang: Wer hier
            // zieht, will den ganzen Schirm neu sehen, nicht nur die
            // Tageswerte. Der Berechtigungs-Provider bleibt ausdrücklich
            // stehen — ein zweiter Dialog käme ohnehin nicht, und ein
            // neuer Lauf darf nicht davon abhängen.
            ref.invalidate(dailyMetricsProvider);
            ref.invalidate(sleepProvider);
            // Auf das Ergebnis warten, nicht nur anstoßen: Sonst klappt
            // die Spirale sofort wieder ein und der Zug sieht aus, als
            // hätte er nichts getan.
            await ref.read(dailyMetricsProvider.future);
          },
        ),
        SliverPadding(
          padding: GlasAbstand.of(context) + const EdgeInsets.only(bottom: 24),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GrosseUeberschrift(
                  'HealthKit-Test',
                  einordnung:
                      'Rohwerte aus Apple Health · ${Format.tag(jetzt)}',
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _standZeile(zustand, jetzt),
                ),
                ..._inhalt(context, zustand),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Die Zeile unter der Überschrift — in **jedem** Zustand, an derselben
/// Stelle. Fiele sie weg, rutschte der ganze Schirm um eine Zeile nach
/// oben, sobald die Werte eintreffen (`CLAUDE.md`, „Eine Anzeige, die es
/// gibt, hat genau eine Form").
///
/// `StandZeile` trägt sie nur im Fall `Bekannt`; die übrigen drei haben
/// keinen Datenstand, den man als „Stand" lesen könnte (so steht es im
/// Klassenkommentar von `StandZeile`, und die Entscheidung, was dort
/// stattdessen erscheint, liegt ausdrücklich beim Aufrufer).
///
/// **„Stand" wäre in `NochNie` nicht ungenau, sondern falsch:** Es wurde
/// nie etwas gelesen und es gibt keinen Zwischenspeicher — es existiert
/// kein Zeitpunkt, den man nennen könnte.
Widget _standZeile(Messwert<List<DailyMetrics>> zustand, DateTime jetzt) {
  const key = Key('healthkit-standzeile');

  return switch (zustand) {
    Bekannt<List<DailyMetrics>> bekannt => StandZeile(
      bekannt,
      jetzt: jetzt,
      key: key,
    ),
    NochNie<List<DailyMetrics>>() => const _Nebenzeile(key: key, 'wird geladen'),
    LeerNachLauf<List<DailyMetrics>>(:final gelaufen) => _Nebenzeile(
      key: key,
      'Nichts gefunden · ${Format.standZeitpunkt(gelaufen, jetzt: jetzt)}',
    ),
    Fehlgeschlagen<List<DailyMetrics>>(:final gelaufen) => _Nebenzeile(
      key: key,
      'Lesen fehlgeschlagen · '
      '${Format.standZeitpunkt(gelaufen, jetzt: jetzt)}',
    ),
  };
}

/// Dieselbe Schrift und Farbe wie `StandZeile`, nur ohne das Wort
/// „Stand" — damit die Zeile an dieser Stelle in jedem Zustand gleich
/// aussieht und gleich hoch ist.
class _Nebenzeile extends StatelessWidget {
  const _Nebenzeile(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    return Text(text, style: TextStyle(fontSize: 12, color: muted));
  }
}

/// Wie eine Zeile ihren Wert zeigt. Der Zustand des Schirms entscheidet
/// das einmal für alle Zeilen — nicht jede Zeile für sich.
enum _Lage {
  /// Noch nie gelesen, kein Zwischenspeicher: graue Form statt Zahl.
  ///
  /// **Nur hier.** Liegt ein Wert vor, bleibt er stehen, auch während neu
  /// gelesen wird — ein Platzhalter, der bei jedem Zug von oben
  /// aufblitzt, ist genau das Flackern, gegen das die Regel gebaut ist.
  laedt,

  /// Lauf fertig, Werte da (einzelne Felder dürfen trotzdem fehlen).
  fertig,

  /// Lauf fertig, nichts gefunden — der Lücken-Satz an jeder Zeile.
  leer,

  /// Lauf gescheitert. Der Grund steht **einmal** oben in der Zeile unter
  /// der Überschrift, nicht an jedem Feld: Dass ein Lauf scheiterte, ist
  /// eine Aussage über den Lauf, nicht über das Feld. Derselbe Schnitt
  /// wie in `HeuteView` (#137).
  gescheitert,
}

/// Hinweis, der an jeder Zeile ohne Wert steht. „Keine Daten" und „kein
/// Lesezugriff" sind für Apple nicht unterscheidbar (CLAUDE.md) — deshalb
/// werden beide Möglichkeiten benannt, statt einen Nullwert vorzutäuschen.
const _keinWertHinweis =
    'Keine Daten oder kein Zugriff — siehe Health-Einstellungen.';

List<Widget> _inhalt(
  BuildContext context,
  Messwert<List<DailyMetrics>> zustand,
) {
  final (lage, werte) = switch (zustand) {
    NochNie<List<DailyMetrics>>() => (_Lage.laedt, const <DailyMetrics>[]),
    Bekannt<List<DailyMetrics>>(:final wert) =>
      wert.isEmpty
          ? (_Lage.leer, const <DailyMetrics>[])
          : (_Lage.fertig, wert),
    LeerNachLauf<List<DailyMetrics>>() => (_Lage.leer, const <DailyMetrics>[]),
    Fehlgeschlagen<List<DailyMetrics>>() => (
      _Lage.gescheitert,
      const <DailyMetrics>[],
    ),
  };

  Color akzent(Color farbe) => CupertinoDynamicColor.resolve(farbe, context);
  final heute = werte.isEmpty ? null : werte.last;

  /// Eine Zeile für ein Feld, das **täglich** entsteht. Fehlt es heute,
  /// ist das eine Aussage: Dann liegt für heute nichts vor.
  Widget taeglich({
    required String feld,
    required String label,
    required String symbol,
    required Color farbe,
    required num? Function(DailyMetrics) lies,
    required String beispiel,
    String einheit = '',
  }) => _zeile(
    feld: feld,
    label: label,
    symbol: symbol,
    akzent: akzent(farbe),
    lage: lage,
    beispiel: beispiel,
    wert: heute == null ? null : _mitEinheit(lies(heute), einheit),
  );

  /// Eine Zeile für ein Feld, das **nicht** täglich entsteht (#237).
  ///
  /// Man wiegt sich nicht jeden Tag. Dass heute keine Wägung vorliegt,
  /// ist der Normalfall und kein Hinweis auf fehlende Daten oder eine
  /// fehlende Freigabe — „keine Daten oder kein Zugriff" nennte hier zwei
  /// Möglichkeiten, von denen keine zutrifft, und verschwiege die dritte,
  /// die zutrifft: Es gibt einen Wert, er ist nur nicht von heute.
  Widget gelegentlich({
    required String feld,
    required String label,
    required String symbol,
    required Color farbe,
    required num? Function(DailyMetrics) lies,
    required String beispiel,
    String einheit = '',
  }) {
    final treffer = _juengster(werte, lies);
    final text = treffer == null
        ? null
        // Die Klammern tragen die Aussage: Der Wert gilt, er ist nur
        // nicht von heute. Ohne sie läse sich die Zeile wie eine heutige
        // Messung. Von heute heißt umgekehrt: ohne Klammer und ohne
        // Datum — die Klammer fällt nur auf, solange sie die Ausnahme
        // ist.
        : treffer.tag == heute?.tag
        ? _mitEinheit(treffer.wert, einheit)
        : '(${_mitEinheit(treffer.wert, einheit)} · ${_tagMonat(treffer.tag)})';

    return _zeile(
      feld: feld,
      label: label,
      symbol: symbol,
      akzent: akzent(farbe),
      lage: lage,
      beispiel: beispiel,
      wert: text,
    );
  }

  return [
    const SectionHeader('Aktivität heute'),
    _karte([
      taeglich(
        feld: 'steps',
        label: 'Schritte',
        symbol: 'figure.walk',
        farbe: Palette.ok,
        lies: (t) => t.steps,
        beispiel: '12.345',
      ),
      taeglich(
        feld: 'activeKcal',
        label: 'Aktive Kalorien',
        symbol: 'figure.run',
        farbe: Palette.river,
        lies: (t) => t.activeKcal,
        einheit: 'kcal',
        beispiel: '1234 kcal',
      ),
      taeglich(
        feld: 'basalKcal',
        label: 'Grundumsatz',
        symbol: 'bolt.fill',
        farbe: Palette.river2,
        lies: (t) => t.basalKcal,
        einheit: 'kcal',
        beispiel: '1234 kcal',
      ),
      taeglich(
        feld: 'exerciseMinutes',
        label: 'Trainingsminuten',
        symbol: 'timer',
        farbe: Palette.iron,
        lies: (t) => t.exerciseMinutes,
        einheit: 'min',
        beispiel: '123 min',
      ),
      taeglich(
        feld: 'standHours',
        label: 'Stehstunden',
        symbol: 'figure.arms.open',
        farbe: Palette.summer,
        lies: (t) => t.standHours,
        einheit: 'h',
        beispiel: '12 h',
      ),
    ]),

    const SectionHeader('Körper, zuletzt gemessen'),
    _karte([
      gelegentlich(
        feld: 'weightKg',
        label: 'Gewicht',
        symbol: 'scalemass',
        farbe: Palette.ok,
        lies: (t) => t.weightKg,
        einheit: 'kg',
        beispiel: '(123,4 kg · 01.11.)',
      ),
      gelegentlich(
        feld: 'bodyFatPct',
        label: 'Körperfett',
        symbol: 'scalemass',
        farbe: Palette.bib,
        lies: (t) => t.bodyFatPct,
        einheit: '%',
        beispiel: '(12,3 % · 01.11.)',
      ),
      gelegentlich(
        feld: 'leanKg',
        label: 'Magermasse',
        symbol: 'scalemass',
        farbe: Palette.iron,
        lies: (t) => t.leanKg,
        einheit: 'kg',
        beispiel: '(123,4 kg · 01.11.)',
      ),
    ]),

    // Die drei Gruppen ohne Provider (#123). **Kein Platzhalter**, auch
    // nicht im Ladezustand: Hier wird nichts geladen, also kommt auch
    // nichts an — eine graue Form verspräche einen Wert, der nie
    // eintrifft, und der Ladezustand wäre dauerhaft.
    //
    // **Je eine Zeile, nicht mehrere.** Der Entwurf zeichnet gefüllt
    // mehrere (zwei Workouts, drei Nächte); wie viele es sind, sagen
    // aber die Daten, und die gibt es hier nicht. Drei Nachtzeilen zu
    // erfinden hieße außerdem, drei Datumsangaben in den Quelltext zu
    // schreiben — ausdrücklich verboten (`CLAUDE.md`, „Keine
    // hartcodierten Ereignisse").
    ..._leereGruppe(
      'Workouts gestern',
      'workouts',
      'Workouts',
      'dumbbell.fill',
      akzent(Palette.iron),
    ),
    ..._leereGruppe(
      'Ernährung gestern',
      'ernaehrung',
      'Mahlzeiten',
      'fork.knife',
      akzent(Palette.bib),
    ),
    ..._leereGruppe(
      'Schlaf, letzte Nächte',
      'schlaf',
      'Nächte',
      'moon.zzz',
      akzent(Palette.river),
    ),

    const SectionHeader('Abgeleitet'),
    _karte([
      taeglich(
        feld: 'restingHR',
        label: 'Ruhepuls',
        symbol: 'heart',
        farbe: Palette.warn,
        lies: (t) => t.restingHR,
        einheit: 'bpm',
        beispiel: '123 bpm',
      ),
      taeglich(
        feld: 'hrvMs',
        label: 'HRV',
        symbol: 'stethoscope',
        farbe: Palette.ok,
        lies: (t) => t.hrvMs,
        einheit: 'ms',
        beispiel: '123,4 ms',
      ),
      taeglich(
        feld: 'respRate',
        label: 'Atmung',
        symbol: 'waveform.path.ecg',
        farbe: Palette.river2,
        lies: (t) => t.respRate,
        einheit: '/min',
        beispiel: '12,34 /min',
      ),
      gelegentlich(
        feld: 'vo2max',
        label: 'VO₂max',
        symbol: 'bolt.fill',
        farbe: Palette.river,
        lies: (t) => t.vo2max,
        beispiel: '(12,34 · 01.11.)',
      ),
      taeglich(
        feld: 'recoveryHRDrop',
        label: 'Erholungspuls-Abfall',
        symbol: 'heart',
        farbe: Palette.river,
        lies: (t) => t.recoveryHRDrop,
        einheit: 'bpm',
        beispiel: '123 bpm',
      ),
    ]),

    const Hinweisfuss(
      'Zum Neulesen von oben ziehen. Die App liest beim Öffnen eines '
      'Schirms und beim Ziehen — nie im Hintergrund; der Stand oben sagt, '
      'wann zuletzt. Ein fehlender Typ heißt entweder „nichts '
      'aufgezeichnet" oder „kein Lesezugriff" — Apple unterscheidet das '
      'nicht. Workouts, Ernährung und Schlaf fragt dieser Schirm noch gar '
      'nicht ab; dort heißt „keine Daten" bis auf Weiteres „noch nicht '
      'angebunden". Ungerundete Rohwerte, keine Bewertung, keine Diagnose.',
    ),
  ];
}

/// Eine Gruppe, für die es noch keinen Provider gibt (#123) — Kopfzeile,
/// eine Zeile, Lücken-Satz. Sie steht in jedem Zustand gleich da, weil
/// sich an ihr auch nichts ändern kann.
List<Widget> _leereGruppe(
  String titel,
  String schluessel,
  String label,
  String symbol,
  Color akzent,
) => [
  SectionHeader(titel),
  _karte([
    KeyedSubtree(
      key: Key('healthkit-gruppe-$schluessel'),
      child: IconRow(
        title: label,
        subtitle: _keinWertHinweis,
        symbol: symbol,
        accent: akzent,
      ),
    ),
  ]),
];

/// Eine Zeile für genau einen HealthKit-Typ. Der Schlüssel sitzt auf einem
/// Vorfahren des erklärenden Inhalts (`KeyedSubtree` um `IconRow`), nicht
/// auf dem `Text` selbst — Vorgabe aus dem Dateikopf der Testdatei.
///
/// Der Erklärtext bei einem fehlenden Wert steht als `subtitle`, nicht als
/// `value`: `value` sitzt in `IconRow` in einer nicht wachsenden Spalte
/// neben dem Titel, ein ganzer Satz dort liefe über den Rand hinaus.
Widget _zeile({
  required String feld,
  required String label,
  required String symbol,
  required Color akzent,
  required _Lage lage,
  required String beispiel,
  required String? wert,
}) {
  final (String? value, String? subtitle, String? platzhalter) = switch (lage) {
    _Lage.laedt => (null, null, beispiel),
    _Lage.fertig when wert != null => (wert, null, null),
    _Lage.fertig || _Lage.leer => (null, _keinWertHinweis, null),
    // Kein Grund je Feld: Der steht einmal oben. `ohneWert` statt einer
    // leeren Spalte, damit die Zeile sichtbar ungefüllt ist statt bloß
    // unfertig auszusehen — und ausdrücklich nicht `0`.
    _Lage.gescheitert => (ohneWert, null, null),
  };

  return KeyedSubtree(
    key: Key('healthkit-typ-$feld'),
    child: IconRow(
      title: label,
      subtitle: subtitle,
      symbol: symbol,
      accent: akzent,
      value: value,
      platzhalter: platzhalter,
    ),
  );
}

/// Trennlinie zwischen den Zeilen, wie in `MehrView._gruppenSpalte`.
Widget _karte(List<Widget> zeilen) => Padding(
  padding: const EdgeInsets.symmetric(horizontal: 20),
  child: InsetCard(child: _KartenSpalte(zeilen: zeilen)),
);

class _KartenSpalte extends StatelessWidget {
  const _KartenSpalte({required this.zeilen});

  final List<Widget> zeilen;

  @override
  Widget build(BuildContext context) {
    final line = CupertinoDynamicColor.resolve(Palette.line, context);

    return Column(
      children: [
        for (var i = 0; i < zeilen.length; i++) ...[
          zeilen[i],
          if (i < zeilen.length - 1)
            Padding(
              padding: const EdgeInsets.only(left: 56),
              child: Container(height: 1, color: line),
            ),
        ],
      ],
    );
  }
}

/// Der jüngste Tag im Fenster, der für dieses Feld einen Wert trägt.
///
/// **Je Feld einzeln gesucht, nicht je Wägung:** Eine Waage liefert
/// Gewicht und Körperfett, aber nicht immer Magermasse. Ein gemeinsames
/// Datum für die ganze Gruppe wäre für mindestens eine Zeile gelogen.
({num wert, String tag})? _juengster(
  List<DailyMetrics> werte,
  num? Function(DailyMetrics) lies,
) {
  for (var i = werte.length - 1; i >= 0; i--) {
    final wert = lies(werte[i]);
    if (wert != null) return (wert: wert, tag: werte[i].tag);
  }
  return null;
}

/// „01.11." aus dem ISO-Tagesschlüssel.
///
/// Über `datumZumAnzeigen`, den Hausweg (`mess_abschnitte.dart`), und
/// **nicht** über `BerlinCalendar.startOfDay`: Das liefert den
/// UTC-Zeitpunkt der Berliner Mitternacht, der vor Mitternacht liegt und
/// sich als Vortag formatiert (am 02.11.2026 genau so passiert). Der
/// Tagesschlüssel ist eine Kalenderangabe, kein Zeitpunkt — er wird als
/// solche gelesen.
String _tagMonat(String isoTag) =>
    Format.tagMonat(datumZumAnzeigen(isoTag));

String? _mitEinheit(num? wert, String einheit) {
  if (wert == null) return null;
  final zahl = _rohzahl(wert);
  return einheit.isEmpty ? zahl : '$zahl $einheit';
}

/// Der Rohwert als Text — **keine** Rundung, **keine** vorgegebene Anzahl
/// Nachkommastellen (CLAUDE.md: „Rohwerte bleiben roh"). Deutsche
/// Zahlschreibweise (Komma statt Punkt), aber sonst unverändert gegenüber
/// `num.toString()`.
String _rohzahl(num wert) {
  if (wert is int) return wert.toString();
  return wert.toString().replaceAll('.', ',');
}
