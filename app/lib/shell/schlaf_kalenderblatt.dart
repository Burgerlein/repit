// Das Kalenderblatt des Schlaf-Schirms (#92) — das Monatsraster hinter dem
// Knopf oben rechts in der Navigationsleiste von `SchlafSeite`.
//
// Eigene Datei, weil `CLAUDE.md` es verlangt: „Views bleiben klein."
//
// **Seit #177 ist jeder Tag des gelesenen Zeitraums antippbar**, auch einer
// ohne Nacht — der Entwurf steht in `docs/screens/screens/schlaf.js`,
// Zustand `kalender`. Vorher war ein leerer Tag stumm, und damit war die
// Eingabe von Hand (#131) nur für Tage erreichbar, an denen schon eine
// gemessene Nacht lag: also genau nicht für den Fall, für den es sie gibt.
//
// **Drei Formen, und jede sagt genau eine Sache:**
//
//   Nacht vorhanden      der **dreigeteilte Schlaf-Ring** der Karte oben,
//                        in klein, Ziffer in `ink`          → antippbar
//   Kein Nacht im
//   gelesenen Zeitraum   **gestrichelter** Ring über den ganzen Kreis,
//                        Ziffer in `ink`                    → antippbar
//   Außerhalb            gar kein Ring, Ziffer in `muted`   → stumm
//
// Gestrichelt heißt auf diesem Schirm schon bei der Messlücke „keine
// Messung" (#156, #168) — dieselbe Sache, dasselbe Zeichen. Ein blasser
// durchgezogener Ring wäre von einem Score nahe null nicht zu
// unterscheiden, und „kein Wert" ist nicht „Wert null" (`docs/SPEC.md` 4.6).
// Gar kein Ring für Tage außerhalb des Zeitraums, weil dort niemand
// nachgesehen hat: Das ist der Unterschied zwischen `LeerNachLauf` und
// `NochNie`, auf dreißig mal dreißig Punkten.
//
// Der Score je Tag kommt aus `SchlafDaten.scores` und ist **derselbe**, den
// die Karte oben zeigt: zwei Wahrheiten über denselben Score wären
// schlimmer als eine langsame. **Seit #243 gilt das auch für sein Bild**
// (Tim: „im Kalender sollen die Ringe die echten Ringe sein, nicht so
// erfundene Farben"): Die Zelle zeichnet die Abschnitte aus
// [schlafTagAbschnitte], und die kommen aus `schlafRingAbschnitte` —
// derselben Funktion, die die Karte benutzt. Vorher trug ein Tag einen
// einfarbigen Bogen in einer von vier Bewertungsfarben; sie hatten keine
// Legende und standen sonst nirgends auf dem Schirm.
//
// **Das Raster hat immer sechs Zeilen** (#258, Tim am 03.11.2026 auf dem
// Gerät: „die Monatsansicht springt je nachdem, wie die Wochen sind"). Wie
// viele ein Monat *braucht*, hängt am Wochentag des Monatsersten und an
// der Monatslänge — daraus werden vier, fünf oder sechs. Sechs ist das
// Maximum, also werden sechs gezeichnet und die überzähligen Felder
// bleiben leer, genau wie die vor dem Monatsersten.
//
// **Nicht über eine feste Höhe für das Blatt.** Die bräche bei größerer
// Schrift; die Zeilenzahl ist die Ursache, nicht die Zellengröße.
//
// **Raster, Kopf, Wischen und Tipp liegen seit #409 in `monatsblatt.dart`**
// — der Ernährungs-Kalender teilt sie. Hier bleibt, was vom Schlaf handelt:
// welche Form ein Tag trägt und der Satz darunter.
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../core/messwert.dart';
import '../design/palette.dart';
import '../design/segment_ring.dart';
import 'monatsblatt.dart';
import 'schlaf_abschnitte.dart';
import 'schlaf_zustand.dart';

/// Welche Form ein Tag im Raster trägt.
///
/// Als Aufzählung und nicht als zwei `bool`, weil es genau drei Fälle gibt
/// und der `switch` darüber vollständig sein muss — käme ein vierter, zeigt
/// der Analyzer jede Stelle an, die ihn nicht behandelt.
enum SchlafTagform {
  /// Für diesen Tag liegt eine Nacht vor.
  nacht,

  /// Im gelesenen Zeitraum, aber ohne Nacht — antippbar, von Hand füllbar.
  leer,

  /// Außerhalb des gelesenen Zeitraums oder in der Zukunft. Dort hat
  /// niemand nachgesehen, also behauptet der Tag auch nichts.
  ausserhalb,
}

/// Die Form eines Tages — die **eine** Stelle, an der das entschieden wird.
///
/// Rein und ohne Widget, damit „ein leerer Tag im Zeitraum ist antippbar"
/// ohne Baum prüfbar bleibt.
SchlafTagform schlafTagform({
  required DateTime tag,
  required bool hatNacht,
  required DateTime fruehesterTag,
  required DateTime heute,
}) {
  if (hatNacht) return SchlafTagform.nacht;
  final hier = BerlinCalendar.startOfDay(tag);
  if (hier.isBefore(BerlinCalendar.startOfDay(fruehesterTag)) ||
      hier.isAfter(BerlinCalendar.startOfDay(heute))) {
    return SchlafTagform.ausserhalb;
  }
  return SchlafTagform.leer;
}

/// Der Ring eines Tages als Abschnitte — die **eine** Stelle, an der aus
/// Form und Score ein Bild wird (#243).
///
/// Mit Nacht sind es die Abschnitte des Schlaf-Rings der Karte oben, über
/// **dieselbe** Rechnung: 50 % Dauer, 30 % Zubettgehzeit, 20 %
/// Unterbrechungen, jedes Segment nach seiner eigenen Teilnote. Tim am
/// 03.11.2026: „im Kalender sollen die Ringe die echten Ringe sein, nicht
/// so erfundene Farben" — vorher trug ein Tag **einen** Bogen in einer von
/// vier Bewertungsfarben, die keine Legende erklärte.
///
/// Die beiden Sonderfälle wandern vom großen Ring mit:
///
/// - **Ohne Zubettgehzeit bleibt das 30-%-Segment stehen**, ohne
///   Grundlage, und wird gestrichelt. Der Ring rechnet nicht auf 70 hoch;
///   sonst sähe eine Nacht ohne Einschlafzeit besser aus, als sie ist.
/// - **Ohne Nacht ein einziger Abschnitt über den ganzen Kreis**, nicht
///   drei leere. Drei leere sähen aus wie eine Nacht mit null Punkten in
///   jedem Teil, und „kein Wert" ist nicht „Wert null" (`docs/SPEC.md`
///   4.6). Seine Farbe ist [Palette.line] und nicht wie oben
///   [Palette.rest]: In einer 30-Punkt-Zelle ist dieser Ring das einzige
///   Zeichen, das den Tag als Tür ausweist — blass wäre er ein Hinweis,
///   den niemand sieht.
///
/// **Außerhalb des gelesenen Zeitraums gar kein Abschnitt.** Dort hat
/// niemand nachgesehen: der Unterschied zwischen `LeerNachLauf` und
/// `NochNie`, auf dreißig mal dreißig Punkten.
List<RingAbschnitt> schlafTagAbschnitte({
  required SleepScore? score,
  required SchlafTagform form,
}) => switch (form) {
  SchlafTagform.ausserhalb => const [],
  SchlafTagform.leer => const [
    RingAbschnitt(
      anteil: 1,
      fuellung: 0,
      farbe: Palette.line,
      hatGrundlage: false,
    ),
  ],
  SchlafTagform.nacht =>
    score == null ? const [] : schlafRingAbschnitte(schlafTeilnoten(score)),
};

/// Das Monatsraster hinter dem Kalenderknopf: ein Ring je Tag, in drei
/// Abschnitte geteilt wie der Schlaf-Ring der Karte oben
/// ([schlafTagAbschnitte]).
///
/// **Blätterbar über die Monate** (#177), begrenzt auf die Monate, die der
/// gelesene Zeitraum berührt. Ohne das wäre der Anfang des Zeitraums
/// unerreichbar, sobald er im Vormonat liegt — bei dreißig Tagen ist das
/// an achtundzwanzig von einunddreißig Tagen im Monat der Fall.
///
/// **Über die Pfeile und über das Raster** (#241, Tim am 03.11.2026: „oben
/// die Pfeile gehen, aber in der Monatsansicht will ich gerne blättern
/// können"). Beide Wege hängen an **denselben** zwei Rückrufen, siehe
/// `build`; die Geste ist [SchlafWischen], dieselbe wie über dem
/// Nachtbereich (#127), und mit ihr kommt der Schutz der linken
/// Systemkante mit.
class SchlafKalenderblatt extends ConsumerStatefulWidget {
  const SchlafKalenderblatt({super.key});

  @override
  ConsumerState<SchlafKalenderblatt> createState() =>
      _SchlafKalenderblattZustand();
}

class _SchlafKalenderblattZustand extends ConsumerState<SchlafKalenderblatt> {
  /// Der gezeigte Monat als sein Erster, **als reines Datum**
  /// ([monatsErster]). `null` heißt „noch nicht geblättert" — dann gilt
  /// der Monat des gezeigten Tages, und der kann sich zwischen zwei Bildern
  /// noch ändern.
  DateTime? _monat;

  @override
  Widget build(BuildContext context) {
    final zustand = ref.watch(schlafProvider);
    final daten = zustand.daten;
    final scores = daten is Bekannt<SchlafDaten>
        ? daten.wert.scores
        : const <DateTime, SleepScore>{};
    final gewaehlt = daten is Bekannt<SchlafDaten>
        ? daten.wert.gezeigterTag
        : ref.watch(schlafAuswahlProvider);

    final heute = zustand.heute;
    final frueheste = zustand.fruehesterTag;
    final monat = _monat ?? monatsErster(gewaehlt ?? heute);
    final auswahl = ref.read(schlafAuswahlProvider.notifier);

    // **Die eine Stelle, an der ein Monatswechsel entsteht.** Pfeil und
    // Wischgeste bekommen denselben Rückruf (#241). `null` heißt „am Rand
    // des gelesenen Zeitraums": Ein Monat, in dem kein Tag antippbar wäre,
    // wird gar nicht erst angeboten (#177).
    final aufFrueher = monatsErster(frueheste).isBefore(monat)
        ? () => setState(() => _monat = monatVerschoben(monat, -1))
        : null;
    final aufSpaeter = monat.isBefore(monatsErster(heute))
        ? () => setState(() => _monat = monatVerschoben(monat, 1))
        : null;

    return Monatsblatt(
      schluessel: 'schlaf-kalender',
      monat: monat,
      heute: heute,
      gewaehlt: gewaehlt,
      aufFrueher: aufFrueher,
      aufSpaeter: aufSpaeter,
      aufTag: auswahl.waehle,
      tag: (tag) {
        final score = scores[tag];
        final form = schlafTagform(
          tag: tag,
          hatNacht: score != null,
          fruehesterTag: frueheste,
          heute: heute,
        );
        // **Gar kein Ring heißt gar kein Ring** — kein leerer Ring, der
        // sich beim Zeichnen wieder verabschiedet.
        final abschnitte = schlafTagAbschnitte(score: score, form: form);
        return MonatsblattTag(
          ring: abschnitte.isEmpty
              ? null
              : (ziffer) => SegmentRingKlein(
                  abschnitte: abschnitte,
                  durchmesser: monatsblattRing,
                  child: ziffer,
                ),
          // **Außerhalb des gelesenen Zeitraums bleibt der Tag stumm.**
          // Dort hat niemand nachgesehen; ihn anzubieten hieße, einen Tag
          // zu wählen, über den der Schirm nichts sagen kann.
          tippbar: form != SchlafTagform.ausserhalb,
        );
      },
      // **Ohne diesen Satz fehlt dem leeren Tag das einzige Zeichen, das
      // ihn als Tür ausweist.** Gestrichelt allein liest sich als
      // „ausgegraut".
      fuss:
          'Jeder Ring ist der Schlaf-Ring der Karte in klein — von '
          'oben im Uhrzeigersinn: Dauer, Zubettgehzeit, '
          'Unterbrechungen. Er gehört zu der Nacht, aus der du an '
          'diesem Morgen aufgewacht bist. Gestrichelt: nicht '
          'gemessen — ein ganzer Ring heißt, für diesen Tag liegt '
          'keine Nacht vor; '
          'antippen und von Hand eintragen. Blasse Tage ohne Ring '
          'liegen außerhalb des gelesenen Zeitraums oder in der '
          'Zukunft.',
    );
  }
}
