// Die Gruppe „Auswertung" des Gym-Schirms (#77) — vier Zeilen in einer
// Karte, in der Reihenfolge aus `docs/screens/screens/gym.js:27–40`.
//
// **Drei der vier haben ihr Ziel** („Fortschritt pro Übung" seit #93,
// „Letzte Trainings" seit #79, „Trainings" seit #533); **eine fehlt noch**
// („Trainierte Muskeln", #96). `CLAUDE.md` sagt für die übrige: „Wo es keine
// Anzeige gibt, gibt es auch keine leere Anzeige; dort steht ein Satz, bis
// das Feature dran ist." Und die Chevron-Regel des Boards sagt: „Der Winkel
// folgt der Tür." Daraus folgt, nach dem Vorbild von `shell/mehr_view.dart`
// (Spec Abschnitt 7):
//
// - Die vier Zeilen stehen sichtbar da, in voller Höhe und an ihrer Stelle.
//   Sie verschwinden nicht und werden nicht durch eine Sammelzeile ersetzt.
// - Die Zeile ohne Ziel trägt keinen Winkel und ist nicht antippbar.
// - Ihr Untertitel bleibt der beschreibende („Welche Muskeln diese Woche zu
//   kurz kommen") — **ohne** die Ankündigung „folgt in einer späteren
//   Aufgabe" (Tim, 19.11.2026, Spec 26 Nr. 4: die Hausregel „ein Satz, bis
//   das Feature dran ist" ist ihm hier zu laut).
// - Ihr Wert bleibt **leer**: nicht `0` und nicht `–/–`. Es gibt keinen
//   Lauf, der leer ausgegangen wäre, und keine Zahl, die noch käme.
//
// Sobald ein Ziel steht, kommen Winkel und `onTap` dazu, und der Wert wird
// gefüllt — je Zeile eine Änderung an genau einer
// Stelle.
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart' show WorkoutNaming;

import '../design/icon_row.dart';
import '../design/inset_card.dart';
import '../design/formatierung.dart';
import '../design/palette.dart';
import '../shell/router.dart';
import 'gym_fortschritt_kennwerte.dart';
import 'gym_fortschritt_view.dart';
import 'gym_provider.dart';
import 'gym_trainings_provider.dart';
import 'gym_trainings_view.dart';
import 'gym_verlauf_view.dart';

/// Die vier Auswertungszeilen.
class GymAuswertung extends StatelessWidget {
  const GymAuswertung({super.key, required this.tag, required this.router});

  final GymTag tag;

  /// Die Tür zu den Detailschirmen — drei Zeilen führen irgendwohin:
  /// „Fortschritt pro Übung" (#93), „Letzte Trainings" (#79) und „Trainings"
  /// (#533).
  final AppRouter router;

  @override
  Widget build(BuildContext context) {
    final line = CupertinoDynamicColor.resolve(Palette.line, context);
    final zeilen = _zeilen();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: InsetCard(
        child: Column(
          children: [
            for (var i = 0; i < zeilen.length; i++) ...[
              if (i > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 56),
                  child: Container(height: 1, color: line),
                ),
              zeilen[i],
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _zeilen() => [
    _Zeile(
      schluessel: const Key('gym-auswertung-fortschritt'),
      symbol: 'bolt.fill',
      akzent: Palette.river,
      titel: 'Fortschritt pro Übung',
      untertitel: 'Höchstgewicht und geschätztes 1RM',
      // Die Breite kommt aus dem Entwurf („4 ↑"); gezeichnet wird sie
      // nie, nur gemessen (siehe `Platzhalter`).
      formBeispiel: '4 ↑',
      laedt: tag.laedt,
      // „4 ↑": für wie viele Übungen mit Verlauf der Vorschlag auf Steigern
      // steht. **Kein „0 ↑" und kein Wert ohne Verlauf** — eine Null
      // behauptete, es sei nachgesehen worden und nichts sei zu steigern
      // (`CLAUDE.md`). Gerechnet wird je Neubau dieser Gruppe, nicht je
      // Bild: Sie baut nur, wenn sich `GymTag` ändert.
      wert: _steigern(),
      // Die Tür steht auch beim Lesen offen: Der Schirm besorgt seine
      // Daten selbst und wartet nicht auf diese Übersicht.
      onTap: () => oeffneGymFortschritt(router),
    ),
    _Zeile(
      schluessel: const Key('gym-auswertung-trainings'),
      symbol: 'list.bullet',
      akzent: Palette.deep,
      titel: 'Letzte Trainings',
      untertitel: _letzteTrainings(),
      formBeispiel: '09.10.',
      laedt: tag.laedt,
      // Der Wert ist der Berliner Tag der jüngsten Sitzung — **kein Wert,
      // wo es keine gibt**: weder `0` noch `–/–` (`CLAUDE.md`).
      wert: _juengsterTag(),
      // Die Tür steht auch beim Lesen offen: Der Verlauf besorgt seine
      // Daten selbst und wartet nicht darauf, dass diese Übersicht
      // geladen hat. `AppTarget.aktuell`, auf den Stapel des Tabs, aus dem
      // man kommt.
      onTap: () => oeffneGymVerlauf(router),
    ),
    _Zeile(
      schluessel: const Key('gym-auswertung-muskeln'),
      symbol: 'figure.run',
      akzent: Palette.ok,
      titel: 'Trainierte Muskeln',
      // Der Entwurf nennt hier die bisher unberührten Muskeln („Waden,
      // hintere Schulter"). Die stehen in keiner Quelle, die dieser Schirm
      // liest: Sie kämen aus dem Verlauf, und den gibt es noch nicht
      // (#59, #78). Drei Muskeln zu nennen, ohne nachgesehen zu haben,
      // wäre eine erfundene Auskunft — bis dahin sagt die Zeile, worum es
      // geht, statt eine Antwort zu behaupten.
      untertitel: 'Welche Muskeln diese Woche zu kurz kommen',
      formBeispiel: '2 ↓',
      laedt: tag.laedt,
    ),
    _TrainingsZeile(router: router, tagLaedt: tag.laedt),
  ];

  /// „4 ↑" — `null`, wo es keine Übung auf Steigern gibt.
  String? _steigern() {
    final anzahl = gymFortschrittSteigernAnzahl(tag.verlauf);
    return anzahl == null ? null : '$anzahl ↑';
  }

  /// „05.03." — der Berliner Tag der jüngsten Sitzung, `null`, solange es
  /// keine gibt.
  String? _juengsterTag() {
    final sitzung = tag.letzteSitzung;
    if (sitzung == null) return null;
    return Format.tagMonat(kalendertag(sitzung.date));
  }

  /// „Gym A · 18 Sätze" aus der jüngsten Sitzung — oder, solange es keine
  /// gibt, der Satz, worum es in der Zeile geht.
  ///
  /// **Keine `0`**: Eine Sitzung ohne Sätze gäbe „0 Sätze", und eine Null
  /// behauptet „nichts getan" (`CLAUDE.md`).
  String _letzteTrainings() {
    final sitzung = tag.letzteSitzung;
    if (sitzung == null || sitzung.setCount < 1) {
      return 'Workout und Sätze der jüngsten Sitzung';
    }
    final name = WorkoutNaming.shortTitle(sitzung) ?? 'Training';
    return '$name · ${sitzung.setCount} Sätze';
  }
}

/// Die Zeile „Trainings" — ersetzt „Alle Pläne" (Spec 7.9, 12 Nr. 7) und
/// führt auf die Trainings-Übersicht.
///
/// **Der Wert ist `readyCount`**: die fertigen, startbaren Trainings —
/// Templates und Eigene, **keine Entwürfe**. Er hängt am Filter der
/// Übersicht nicht. Die Zeile liest ihn selbst (`gymTrainingsProvider`),
/// beobachtet aber nur das, was sie zeigt: ein neu gelesener Stand mit
/// gleicher Zahl baut sie nicht neu.
///
/// - **Beim ersten Lesen eine graue Form, nie „0"** (Fehler `01`). Danach
///   bleibt die Zahl stehen, auch während neu gelesen wird.
/// - **Ohne fertiges Training keine Zahl:** „Gelesen und leer" lässt sich
///   von „Lesen gescheitert" nicht unterscheiden, und eine `0` behauptete
///   „keine Trainings", wo vielleicht nur nicht gelesen werden konnte.
/// - **Der Schlüssel bleibt `gym-auswertung-plaene`** (Spec 7.9): Die Tests
///   führen ihn weiter.
/// - **Die Tür steht auch beim Lesen offen:** Die Übersicht besorgt ihre
///   Daten selbst.
class _TrainingsZeile extends ConsumerWidget {
  const _TrainingsZeile({required this.router, required this.tagLaedt});

  final AppRouter router;

  /// [GymTag.laedt] — wie bei den anderen Zeilen steht die graue Form, solange
  /// der Tag gelesen wird. Eine Zahl, die schon da ist, schlägt sie.
  final bool tagLaedt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stand = ref.watch(
      gymTrainingsProvider.select(
        (s) => (laedt: s.laedt, anzahl: s.readyCount),
      ),
    );

    return _Zeile(
      schluessel: const Key('gym-auswertung-plaene'),
      symbol: 'list.bullet',
      akzent: Palette.rest,
      // `rest` ist ein sehr helles Grau; ein weißes Symbol darauf wäre
      // unsichtbar. Der Entwurf setzt dort `iconTint: 'ink'`
      // (`gym.js:49`).
      symbolFarbe: Palette.ink,
      titel: 'Trainings',
      untertitel: 'Templates und Eigene, anlegen und teilen',
      // Die Breite kommt aus dem Entwurf („5"); gezeichnet wird sie nie,
      // nur gemessen (siehe `Platzhalter`).
      formBeispiel: '5',
      laedt: tagLaedt || stand.laedt,
      wert: stand.laedt || stand.anzahl < 1 ? null : '${stand.anzahl}',
      onTap: () => oeffneGymTrainings(router),
    );
  }
}

/// Eine Auswertungszeile — sichtbar. Ohne Ziel: ohne Winkel, ohne Wert, mit
/// seinem beschreibenden Untertitel. Mit Ziel: Winkel, Antippen und — wo es
/// ihn gibt — der Wert.
class _Zeile extends StatelessWidget {
  const _Zeile({
    required this.schluessel,
    required this.symbol,
    required this.akzent,
    required this.titel,
    required this.untertitel,
    required this.formBeispiel,
    required this.laedt,
    this.symbolFarbe,
    this.wert,
    this.onTap,
  });

  final Key schluessel;
  final String symbol;
  final Color akzent;
  final String titel;
  final String untertitel;

  /// Beispieltext für die graue Form, die während des Lesens an der Stelle
  /// des Werts steht.
  final String formBeispiel;

  final bool laedt;
  final Color? symbolFarbe;

  /// Der Wert rechts — `null`, wo es keinen gibt.
  final String? wert;

  /// Das Ziel. `null`: Es gibt keins — die Zeile trägt dann weder Winkel
  /// noch Antipp-Auslöser.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: schluessel,
      child: IconRow(
        symbol: symbol,
        accent: akzent,
        symbolFarbe: symbolFarbe,
        title: titel,
        // Ohne Ziel steht keine Ankündigung am Untertitel (Spec 26 Nr. 4).
        subtitle: untertitel,
        // **Ohne Ziel kein `onTap`** — und damit kein Winkel: Eine Zeile,
        // die aussieht wie ein Knopf und beim Tippen schweigt, ist genau
        // der gesuchte Fehler.
        onTap: onTap,
        value: wert,
        // Der Wert bleibt leer. Die graue Form steht **allein** während
        // des Lesens da (`CLAUDE.md`: „Der Platzhalter gehört allein in
        // den Ladezustand") — ihr Platz bleibt aber auch danach
        // reserviert, sonst bekäme der Untertitel daneben mehr Raum,
        // bräche eine Zeile weniger um, und die Karte spränge zwischen
        // „lädt" und „fertig".
        platzhalter: formBeispiel,
        platzhalterSichtbar: laedt,
      ),
    );
  }
}
