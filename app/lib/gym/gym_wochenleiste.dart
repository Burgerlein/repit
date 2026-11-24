// Die Wochenleiste „Diese Woche" des Gym-Schirms (#77) — Dart-Entsprechung
// von `Sources/Features/Gym/GymWeekStrip.swift`, gezeichnet nach
// `weekStrip(slots)` in `docs/screens/components.js` (`.strip` in
// `components.css`).
//
// **Die Leiste filtert nicht und zählt nicht nach.** Welche Plätze sie hat,
// sagt `GymDayPlanner` aus der gespeicherten Rotation (`gymRotationProvider`,
// Spec 23/24): Push, Pull, Legs zum Start, nach dem Löschen eines Templates
// entsprechend weniger — **null bis drei Plätze**. Täte der Schirm dasselbe
// ein zweites Mal, gäbe es zwei Stellen für dieselbe Zusage, und nur eine
// davon würde später angepasst (Spec Abschnitt 6).
//
// **Die Leiste behält ihre Form** (`CLAUDE.md`): Die Kacheln teilen sich die
// Breite, also hat sie bei einem, zwei und drei Plätzen dieselbe Höhe und
// Breite; **ohne Platz steht ein Satz in der Form der Leiste** da
// ([kGymWocheLeer]). Solange noch nicht gelesen wurde, stehen
// [gymStartRotation]`.length` graue Kacheln da — nie ein Statustext und nie
// der leere Satz.
//
// **Die Kachel führt ins Erfassen** (#78): In Swift ist es
// `router.openGym(.log(workout))`, hier `oeffneGymLog` — auf den Stapel des
// Tabs, aus dem man kommt. Das ist der Weg, ein Training anzufangen, solange
// es keinen Plan gibt (#64, #81), der „Training starten" anbietet. Solange
// gelesen wird, ist sie nicht antippbar: Noch ist nicht klar, ob schon ein
// anderes Training läuft.
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:trainings_core/trainings_core.dart';

import '../design/karten_flaeche.dart';
import '../design/palette.dart';
import '../design/platzhalter.dart';
import '../design/typografie.dart';
import '../shell/router.dart';
import 'gym_log_view.dart';
import 'gym_trainings_provider.dart' show gymStartRotation;
import 'gym_wochen_texte.dart';

/// Der Schlüssel des Satzes, der steht, wenn die Rotation leer ist.
const kGymWocheLeer = Key('gym-woche-leer');

/// Die Plätze der Woche als Kachelreihe — null bis drei.
///
/// [laedt] ist [GymTag.laedt]: Solange noch keine Quelle geantwortet hat,
/// stehen die Kacheln in **derselben Größe** da, ihre Inhalte aber als graue
/// Formen. Dreimal „offen" wäre sonst eine Aussage über eine Datenlage, in
/// die noch niemand gesehen hat — Fehler `01` in neuer Verpackung
/// (Spec Abschnitt 9.3). Weiß die Leiste noch nicht, wie viele Plätze es
/// werden (die Rotation ist noch nicht gelesen), stehen so viele graue
/// Kacheln da, wie die Startbefüllung Plätze hat.
class GymWochenleiste extends StatelessWidget {
  const GymWochenleiste({
    super.key,
    required this.woche,
    required this.heute,
    required this.laedt,
    required this.router,
  });

  final List<GymSlot> woche;

  /// Die Tür zum Erfassen.
  final AppRouter router;

  /// Der Berliner Tagesbeginn aus `heutigerTagProvider` — die Leiste
  /// braucht ihn, um aus `GymSlot.weekday` einen Namen zu machen.
  final DateTime heute;

  final bool laedt;

  /// Abstand zwischen zwei Kacheln (`.strip { gap: 8px }`).
  static const _abstand = 8.0;

  @override
  Widget build(BuildContext context) {
    // Noch nicht gelesen und noch kein Platz bekannt: so viele graue Kacheln,
    // wie die Startbefüllung hat. Sind Plätze da (auch bei `laedt`, etwa mit
    // einem hereingereichten Stand), zählen die.
    final unbekannt = woche.isEmpty && laedt;
    if (woche.isEmpty && !laedt) return const _LeereWoche();

    final plaetze = unbekannt ? gymStartRotation.length : woche.length;
    // Die Breite der Kacheln ist die von **dreien**, auch wenn es weniger
    // sind: Teilten sich die verbliebenen den Platz, spränge ihre Breite
    // beim Löschen eines Templates (`CLAUDE.md`, „Eine Anzeige, die es gibt,
    // hat genau eine Form"). Leere Spalten bleiben leer.
    final spalten = math.max(plaetze, gymStartRotation.length);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      // `IntrinsicHeight`, damit alle Kacheln so hoch sind wie die
      // höchste — `CrossAxisAlignment.stretch` allein bekäme in einer
      // scrollenden Spalte eine unendliche Höhe. Drei kleine Kacheln sind
      // billig genug dafür; gemessen wird vor dem Commit (Spec
      // Abschnitt 12).
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < spalten; i++) ...[
              if (i > 0) const SizedBox(width: _abstand),
              Expanded(
                child: i >= plaetze
                    ? const SizedBox.shrink()
                    : _Platz(
                        platz: unbekannt ? null : woche[i],
                        heute: heute,
                        laedt: laedt,
                        router: router,
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Die Stile der Kachel — an **einer** Stelle, weil [_LeereWoche] die Höhe
/// einer Kachel nachmisst und dieselben Schriften braucht.
class _Stile {
  _Stile(BuildContext context)
    : tag = TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        color: CupertinoDynamicColor.resolve(Palette.muted, context),
      ),
      workout = Typografie.numeric(
        TypografieGroesse.headline,
        gewicht: FontWeight.w700,
      ).copyWith(color: CupertinoDynamicColor.resolve(Palette.ink, context)),
      status = TextStyle(
        fontSize: 11,
        color: CupertinoDynamicColor.resolve(Palette.muted, context),
      );

  final TextStyle tag;
  final TextStyle workout;
  final TextStyle status;

  /// Innenabstand der Kachel: oben 10, unten 11, seitlich 6.
  static const innen = EdgeInsets.fromLTRB(6, 10, 6, 11);

  /// Die Höhe einer Kachel mit einzeiligem Status — gemessen, nicht
  /// geschrieben.
  double kachelHoehe(BuildContext context) =>
      innen.vertical +
      textMass(context, 'MO.', tag).height +
      2 +
      textMass(context, 'Push', workout).height +
      1 +
      textMass(context, 'offen', status).height;
}

/// Die leere Woche: **ein Satz in der Form der Leiste** — Kachelfläche, Höhe
/// einer Kachel, volle Breite. Er steht nur, wenn gelesen wurde und keine
/// Rotation da ist (alle Templates gelöscht, Spec 24 Nr. 1); beim Lesen
/// stehen graue Kacheln da, nie dieser Satz.
class _LeereWoche extends StatelessWidget {
  const _LeereWoche();

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        height: _Stile(context).kachelHoehe(context),
        child: DecoratedBox(
          decoration: kartenFlaeche(context),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                gymWocheLeerText,
                key: kGymWocheLeer,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: muted),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Eine Kachel: Wochentag, Workout, Status — und oben der Farbbalken, in dem
/// allein das Statussignal lebt.
class _Platz extends StatelessWidget {
  const _Platz({
    required this.platz,
    required this.heute,
    required this.laedt,
    required this.router,
  });

  /// `null`: Es ist noch nicht bekannt, welches Training den Platz bekommt
  /// (die Rotation ist noch nicht gelesen) — die Kachel steht als graue Form
  /// da, ohne Schlüssel und ohne Tür.
  final GymSlot? platz;
  final DateTime heute;
  final bool laedt;
  final AppRouter router;

  /// Der Balken oben, in dem allein das Statussignal lebt
  /// (`GymWeekStrip.tile`).
  static const _balkenHoehe = 3.0;

  @override
  Widget build(BuildContext context) {
    final platz = this.platz;
    // Ohne Platz (noch nicht gelesen) steht die Kachel als offener Platz da —
    // nur ihre Farben; der Text ist ohnehin eine graue Form.
    final status = platz?.status ?? const Open();
    final iron = CupertinoDynamicColor.resolve(Palette.iron, context);
    final hervor = gymWochenHervorgehoben(status);

    final stile = _Stile(context);
    final tagStil = stile.tag;
    final workoutStil = stile.workout;
    final statusStil = stile.status.copyWith(
      color: CupertinoDynamicColor.resolve(
        gymWochenStatusFarbe(status),
        context,
      ),
    );
    // Der Platz, dessen Inhalt wirklich dasteht — keiner, solange gelesen
    // wird: dann ist alles eine graue Form.
    final slot = laedt ? null : platz;

    // Name, Tag und Zustand stehen **zentriert** in der Kachel (Tim,
    // 19.11.2026, Spec 26 Nr. 5). `Stack` gibt seinen nicht positionierten
    // Kindern lockere Maße, die Spalte schrumpfte sonst auf ihren Inhalt und
    // säße links — die volle Breite kommt aus dem `SizedBox`.
    final inhalt = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Die Beispieltexte der grauen Formen werden **nie gezeichnet**,
        // nur gemessen (siehe [Platzhalter]). Sie stehen hier, damit die
        // Form so hoch und so breit ist wie das, was sie ablöst.
        if (slot == null)
          Platzhalter(beispiel: 'MO.', stil: tagStil)
        else
          Text(
            gymWochenTag(slot, heute: heute),
            style: tagStil,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        const SizedBox(height: 2),
        if (slot == null)
          Platzhalter(beispiel: 'Push', stil: workoutStil)
        else
          Text(
            slot.workout.label,
            style: workoutStil,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        const SizedBox(height: 1),
        if (slot == null)
          Platzhalter(beispiel: 'offen', stil: statusStil)
        else
          Text(
            gymWochenStatus(status),
            style: statusStil,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
      ],
    );

    // Erst auflegen, dann beschneiden: Ein 3 Punkt hoher Balken mit
    // 17 Punkt Eckenradius liefe sonst über die Ecke hinaus (`CLAUDE.md`,
    // Abschnitt Code). Dasselbe gilt für die Umrandung des heutigen
    // Workouts — sie liegt als Vordergrunddekoration über der schon
    // beschnittenen Kachel.
    //
    // **Fläche und Radius kommen aus [kartenFlaeche]**, nicht aus eigenen
    // Zahlen: Die Kachel steht im Board in derselben Liste wie jede andere
    // Karte (`components.css:206`, #384) — `surface`, Radius 17, kein Rand.
    // Die Swift-Vorlage zeichnet dort noch Radius 14 und einen 1 Punkt
    // breiten Rand; der ist mit #384 app-weit gefallen. Der **zwei** Punkt
    // breite Ring in `iron` bleibt, denn er ist kein Rahmen, sondern das
    // Signal „das ist das heutige" (Spec Abschnitt 6).
    final kachel = DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(kartenRadius),
        border: hervor ? Border.all(color: iron, width: 2) : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kartenRadius),
        child: DecoratedBox(
          decoration: kartenFlaeche(context),
          child: Stack(
            children: [
              Padding(
                padding: _Stile.innen,
                child: SizedBox(width: double.infinity, child: inhalt),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: _balkenHoehe,
                child: ColoredBox(
                  color: CupertinoDynamicColor.resolve(
                    gymWochenBalken(status),
                    context,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Semantics(
      key: platz == null ? null : Key('gym-woche-platz-${platz.workout.code}'),
      container: true,
      // **Der Vorlesetext nennt den Zustand, nicht das Zeichen**
      // (`CLAUDE.md`): „Push, offen" statt „MO. Push offen" — und erst recht
      // statt „— Push offen", wo kein Tag feststeht. Solange gelesen wird,
      // steht dort, dass gelesen wird; „offen" wäre dann gelogen.
      label: platz == null
          ? 'wird geladen'
          : laedt
          ? '${platz.workout.label}, wird geladen'
          : gymWochenVorlesetext(platz),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: slot == null ? null : () => oeffneGymLog(router, slot.workout),
        child: Opacity(
          opacity: gymWochenAbgeblendet(status) ? 0.45 : 1,
          child: kachel,
        ),
      ),
    );
  }
}
