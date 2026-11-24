// Die Fokus-Karte des Gym-Schirms (#77) — Dart-Entsprechung von
// `FocusCard` (`Sources/DesignSystem/FocusCard.swift`), gefüllt wie
// `focusCard({accent, pill, title, subtitle, progress, progressLabel,
// actions, footer})` in `docs/screens/components.js`.
//
// **Die einzige Verzweigung dieses Schirms ist `GymDay.focus`** mit seinen
// vier Fällen. Der `switch` darüber ist vollständig; käme ein fünfter Fall,
// meldet der Analyzer jede Stelle, die ihn nicht behandelt (Spec
// Abschnitt 5).
//
// **Es gibt keinen Zustand ohne diese Karte** und keinen ohne Knopf. Was
// fehlt, fehlt als `null` — nicht als leerer Text und nicht als Null.
//
// **Kein Glas.** Die Karte ist zwar eine „Fokus-Karte" im Sinne der
// Glasregel, liegt aber in einer Liste mit Scrollinhalt; die Shader-Last ist
// real, und der Entwurf zeichnet sie als normale Karte mit Akzentkante
// (`CLAUDE.md`, Spec Abschnitt 5.5).
import 'package:flutter/cupertino.dart';
import 'package:trainings_core/trainings_core.dart';

import '../design/palette.dart';
import '../design/platzhalter.dart';
import '../design/typografie.dart';
import '../shell/router.dart';
import 'gym_fokus_fuss.dart';
import 'gym_fokus_knoepfe.dart';
import 'gym_fokus_texte.dart';
import 'gym_ladeform.dart';
import 'gym_provider.dart';
import 'gym_vorschlag_texte.dart';

/// Die Karte oben auf dem Gym-Tab.
///
/// [laedt] aus [GymTag] entscheidet **nur über die Füllung**: Kapsel, Titel,
/// Untertitel und Knopfbeschriftung stehen dann als graue Formen in
/// derselben Geometrie da. Der Satz „Diese Woche ist das Krafttraining
/// durch." ist eine Aussage über eine Datenlage und darf erst stehen, wenn
/// wirklich nachgesehen wurde (Fehler `01`, Spec Abschnitt 9.3).
class GymFokusKarte extends StatelessWidget {
  const GymFokusKarte({
    super.key,
    required this.tag,
    required this.heute,
    required this.router,
  });

  final GymTag tag;

  /// Die Tür zum Erfassen — die Knöpfe „Weiter eintragen", „Training
  /// starten" und „vorziehen" führen dorthin.
  final AppRouter router;

  /// Der Berliner Tagesbeginn aus `heutigerTagProvider` — der Untertitel
  /// des Ruhetags macht daraus den Namen des nächsten Trainingstags.
  final DateTime heute;

  /// Breite der farbigen Kante (`.card.focus::before { width: 5px }`).
  static const _kanteBreite = 5.0;

  /// Eckenradius der Fokus-Karte (`--r-live`), größer als der jeder anderen
  /// Karte.
  static const _radius = 22.0;

  /// **Feste Zeilenzahl für den Untertitel** (`FesteZeilen`, #24).
  ///
  /// Er schwankt zwischen einer Zeile (`inProgress`) und dreien: Im Ruhetag
  /// steht „Laut Plan: …" über „Nächstes Krafttraining: …", und die zweite
  /// davon bricht auf der schmalen Karte um. Fällt sie weg, weil `next`
  /// fehlt, rutschte ohne feste Höhe alles darunter nach oben — genau der
  /// Sprung, den die Leerzustandsregel verhindern soll.
  static const _untertitelZeilen = 3;

  @override
  Widget build(BuildContext context) {
    final focus = tag.tag.focus;
    final akzent = CupertinoDynamicColor.resolve(
      gymFokusAkzent(focus),
      context,
    );
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);

    final titelStil = Typografie.numeric(
      TypografieGroesse.title2,
      gewicht: FontWeight.w700,
    ).copyWith(color: ink);
    final untertitelStil = TextStyle(fontSize: 15, height: 1.3, color: muted);

    final fuss = _fuss();

    final inhalt = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 17, 19, 17),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Kapsel(
                key: const Key('gym-fokus-kapsel'),
                text: gymFokusKapsel(focus),
                akzent: akzent,
                laedt: tag.laedt,
              ),
              Padding(
                key: const Key('gym-fokus-titel'),
                padding: const EdgeInsets.only(top: 9),
                child: GymTextOderForm(
                  text: gymFokusTitel(focus),
                  stil: titelStil,
                  laedt: tag.laedt,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: FesteZeilen(
                  key: const Key('gym-fokus-untertitel'),
                  zeilen: _untertitelZeilen,
                  stil: untertitelStil,
                  child: GymTextOderForm(
                    text: gymFokusUntertitel(
                      focus,
                      heute: heute,
                      zuletzt: _zuletzt(tag),
                      leereWoche: tag.tag.week.isEmpty,
                    ),
                    stil: untertitelStil,
                    laedt: tag.laedt,
                    formBeispiel: 'Laut Plan: Spaziergang 30–45 min',
                  ),
                ),
              ),
              if (focus is InProgress)
                _Fortschritt(
                  key: const Key('gym-fokus-fortschritt'),
                  focus: focus,
                  akzent: akzent,
                  laedt: tag.laedt,
                ),
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: GymAktionen(
                  key: const Key('gym-fokus-aktionen'),
                  focus: focus,
                  akzent: akzent,
                  laedt: tag.laedt,
                  router: router,
                ),
              ),
            ],
          ),
        ),
        ?fuss,
      ],
    );

    // Erst auflegen, dann beschneiden (`CLAUDE.md`, Abschnitt Code): Ein
    // 5 Punkt breiter Balken mit 22 Punkt Eckenradius liefe sonst über die
    // Ecke hinaus. Die Kante selbst zu runden geht nicht auf.
    return ClipRRect(
      borderRadius: BorderRadius.circular(_radius),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: CupertinoDynamicColor.resolve(Palette.surface, context),
        ),
        child: Stack(
          children: [
            inhalt,
            Positioned(
              top: 0,
              bottom: 0,
              left: 0,
              width: _kanteBreite,
              child: ColoredBox(color: akzent),
            ),
          ],
        ),
      ),
    );
  }

  /// Die Fußzeile — `null`, wo es keine gibt.
  ///
  /// Solange gelesen wird, steht hier nichts: Jede der vier Formen nennt
  /// einen Befund (die nächste Übung, ein liegen gebliebenes Workout), und
  /// ein Befund vor dem Nachsehen wäre Fehler `01`.
  Widget? _fuss() {
    if (tag.laedt) return null;
    final focus = tag.tag.focus;

    switch (focus) {
      case InProgress(:final workout, :final done):
        // Die nächste Übung eines eigenen Trainings steht nicht im Fall,
        // sondern in seiner Definition: dort keine Fußzeile.
        if (workout == null) return null;
        final uebungen = ExerciseCatalog.exercisesFor(workout);
        // „solange `done` innerhalb der Liste liegt, sonst keine Fußzeile"
        // (Spec Abschnitt 5.1).
        if (done < 0 || done >= uebungen.length) return null;
        final uebung = uebungen[done];
        final saetze = tag.verlauf[uebung.id] ?? const <List<CompletedSet>>[];
        final hatVerlauf = saetze.isNotEmpty;
        final vorschlag = Progression.suggest(uebung, saetze);
        return GymFussZeile(
          key: const Key('gym-fokus-fuss'),
          symbol: 'dumbbell.fill',
          akzent: Palette.iron,
          titel: gymNaechsteUebungTitel(uebung),
          untertitel: gymUebungDetailText(
            uebung,
            vorschlag,
            hatVerlauf: hatVerlauf,
          ),
          // **Ohne Verlauf kein Gewicht**, sondern nur der Hinweis auf den
          // Wiederholungsbereich im Untertitel. „0 kg" wäre Fehler `01`
          // (Spec Abschnitt 5.1).
          wert: hatVerlauf ? vorschlagZielgewichtText(vorschlag, uebung) : null,
        );

      case Planned(:final workout):
        return GymUebungsVorschau(
          key: const Key('gym-fokus-fuss'),
          workout: workout,
          verlauf: tag.verlauf,
        );

      case Rest(:final overdue):
        if (overdue == null) return null;
        return GymFussZeile(
          key: const Key('gym-fokus-fuss'),
          symbol: 'dumbbell.fill',
          akzent: Palette.bib,
          titel: gymOffenTitel(overdue),
          untertitel: gymOffenUntertitel,
        );

      case Recovery():
        return const GymFussZeile(
          key: Key('gym-fokus-fuss'),
          symbol: 'checkmark',
          akzent: Palette.muted,
          titel: gymErholungFussTitel,
          untertitel: gymErholungFussText,
        );
    }
  }
}

/// Wann **dieses** Workout zuletzt abgeschlossen wurde — für den Zusatz
/// „· zuletzt …" im Untertitel des Zustands `planned`.
///
/// **[GymTag.letzteSitzung] trägt die jüngste Sitzung über alle Workouts**,
/// der Untertitel will aber den letzten Abschluss genau dieses einen. Der
/// Zusatz erscheint deshalb nur, wenn beide dasselbe Workout meinen; sonst
/// behauptete die Karte, Push sei am Donnerstag gelaufen, obwohl es Legs
/// war. Lieber kein Zusatz als ein falscher.
///
/// Heute ist das Feld ohnehin immer `null` — es gibt keine Gym-Ablage
/// (#59, #78). Die Regel steht hier, damit sie steht, bevor es die Daten
/// gibt.
DateTime? _zuletzt(GymTag tag) {
  final focus = tag.tag.focus;
  if (focus is! Planned) return null;
  final sitzung = tag.letzteSitzung;
  if (sitzung == null || sitzung.workout != focus.workout) return null;
  return sitzung.date;
}

/// Die Kapsel über der Überschrift: „Angefangen", „Heute", „Heute kein
/// Gym", „Pause".
///
/// **Ohne Versalien**, anders als `FocusPill` in Swift
/// (`Text(text.uppercased())`): `app/test/gym/gym_view_test.dart` vergleicht
/// den Text unter diesem Schlüssel Zeichen für Zeichen mit
/// [gymFokusKapsel], und ein `Text(…​.toUpperCase())` trüge die versale
/// Fassung als seinen Inhalt. Der Sperrsatz bleibt.
class _Kapsel extends StatelessWidget {
  const _Kapsel({
    super.key,
    required this.text,
    required this.akzent,
    required this.laedt,
  });

  final String text;
  final Color akzent;
  final bool laedt;

  @override
  Widget build(BuildContext context) {
    final stil = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
      color: akzent,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: akzent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: GymTextOderForm(text: text, stil: stil, laedt: laedt),
      ),
    );
  }
}

/// Der Fortschrittsbalken samt Beschriftung — **ausschließlich bei
/// `InProgress`.**
///
/// Es gibt keinen Balken auf 0 %, weil kein Entwurf vorliegt: Ein Ring oder
/// Balken auf Null behauptet „nichts getan", und das ist Fehler `01` in
/// neuer Verpackung (`CLAUDE.md`).
class _Fortschritt extends StatelessWidget {
  const _Fortschritt({
    super.key,
    required this.focus,
    required this.akzent,
    required this.laedt,
  });

  final InProgress focus;
  final Color akzent;
  final bool laedt;

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final anteil = (focus.done / (focus.total < 1 ? 1 : focus.total)).clamp(
      0.0,
      1.0,
    );
    final stil = TextStyle(fontSize: 14, color: muted);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 13),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              width: double.infinity,
              height: 5,
              child: ColoredBox(
                color: CupertinoDynamicColor.resolve(Palette.line, context),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: anteil,
                  child: ColoredBox(color: akzent),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: GymTextOderForm(
            text: gymFokusFortschrittText(done: focus.done, total: focus.total),
            stil: stil,
            laedt: laedt,
          ),
        ),
      ],
    );
  }
}
