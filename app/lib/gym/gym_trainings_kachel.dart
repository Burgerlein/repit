// Die Kachel der Trainings-Übersicht und ihr grauer Platzhalter (#533 unter
// #531, Task 2.3; Spec 7.2, 7.3, 7.5) — gebaut nach `trainingTile` und
// `muscleThumb` in `docs/screens/components.js` (`.traintile` in
// `components.css`).
//
// **Aufbau wörtlich nach Tim (18.11.2026):** Muskelkarte ganz links, Trenner,
// Name, darunter die Dauer und die Tags, hinten die Zahl der Übungen.
//
// **Eine Form, in jeder Lage** (`CLAUDE.md`): Die Kachel hat ihre Höhe, auch
// ohne Tags, als Entwurf, ohne Dauer („–") — die Tag-Zeile ist reserviert, die
// Figurspalte gibt die Mindesthöhe vor. Der Platzhalter ([GymTrainingKachelLaedt])
// ist **dieselbe Form in Grau**: dieselben Maße, dieselbe Fläche.
//
// **Die Figur dreht sich per Zug** (Spec 7.5, Tim 19.11.2026), ein Tipp auf
// die Kachel — auch auf die Figur — öffnet das Detail. Die Fläche des Zugs ist
// die Figur samt den zwei Punkten, **nicht** die ganze Kachel:
//
// - Ein Zug in **jede** Richtung wechselt die Seite — es gibt nur zwei.
// - Gerechnet wird **ein** Zug über seine zurückgelegte Strecke
//   (`onHorizontalDragUpdate`), nicht über sein Ende: Ein einzelner
//   `onHorizontalDragEnd` auf einer Fläche, die nicht scrollt, bekäme beim
//   Loslassen auch einen senkrechten Zug zugesprochen und drehte ihn.
//   Senkrechte Züge tragen waagerecht nichts bei — sie gehören dem Scrollen.
// - **Die Figur sitzt mindestens 34 Punkt vom linken Rand** (20 Rand der Liste,
//   14 Innenabstand der Kachel): Der Zurück-Wisch der Seitenroute reagiert auf
//   den äußeren Streifen und gewinnt sonst gegen den Dreh-Zug. Das sieht kein
//   Widget-Test — es steht in der Prüfanleitung (Spec 7.5).
// - **VoiceOver kann nicht wischen:** Die Figur trägt die Aktion „Figur
//   umdrehen". Ihr Vorlesetext nennt die Seite **und** die Muskeln.
//
// **Die Seite gehört dem Schirm, nicht der Kachel**
// (`gymTrainingsSeiteProvider`): Sie überlebt Detail und Zurück (Fehler `32`).
// **Keine Hero-Tags** (flutter#25218).
//
// **Gefärbt wird einfarbig** in `Palette.iron`: Die Kachel sagt „trifft diese
// Muskeln", nicht „wie viel" — das ist die Muskelkarte (Spec 7.2, 8.1).
import 'package:flutter/cupertino.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../design/karten_flaeche.dart';
import '../design/muskel_figur.dart';
import '../design/palette.dart';
import '../design/platzhalter.dart';
import '../shell/router.dart';
import 'gym_editor_provider.dart' show GymEditorQuelle;
import 'gym_trainings_provider.dart';
import 'gym_trainings_schluessel.dart';
import 'gym_trainings_texte.dart';
import 'gym_training_detail_view.dart';
import 'gym_training_editor_view.dart' show oeffneGymEditor;

/// Die Maße der Kachel (`.traintile`, `.tfig`).
const double _figurBreite = 34;
const double _figurHoehe = 60;
const double _punkteHoehe = 4;
const double _figurAbstand = 2;

/// Die Höhe der Figurspalte: Figur, Abstand, Punkte. Sie ist die Mindesthöhe
/// der Kachel — der Text daneben ist niedriger, also ist jede Kachel gleich
/// hoch.
const double _figurSpalte = _figurHoehe + _figurAbstand + _punkteHoehe;

/// Die Tag-Zeile: auch ohne Tags und ohne Kapsel **reserviert** (Spec 7.2).
const double _tagZeile = 17;

/// Der Zug, ab dem die Figur die Seite wechselt — gemessen **nach** der
/// Touch-Schwelle, die Flutter schon abzieht.
const double _dreh = 12;

/// Die Fläche der Kachel: Karte, Mindesthöhe, Innenabstand — für die echte
/// Kachel und ihren Platzhalter **dieselbe**.
class _Rahmen extends StatelessWidget {
  const _Rahmen({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: DecoratedBox(
        decoration: kartenFlaeche(context),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 76),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Die Stile der Kachel — für die echte Kachel und den Platzhalter gleich,
/// damit die graue Form so hoch ist wie der Text, den sie ablöst.
class _Stile {
  _Stile(BuildContext context)
    : name = TextStyle(
        fontSize: 16.3,
        fontWeight: FontWeight.w600,
        color: CupertinoDynamicColor.resolve(Palette.ink, context),
      ),
      sub = TextStyle(
        fontSize: 12.8,
        color: CupertinoDynamicColor.resolve(Palette.muted, context),
      ),
      anzahl = TextStyle(
        fontSize: 12.8,
        color: CupertinoDynamicColor.resolve(Palette.muted, context),
      );

  final TextStyle name;
  final TextStyle sub;
  final TextStyle anzahl;
}

/// Eine Kachel der Übersicht.
///
/// [router] ist die Tür: Ein Tipp öffnet das Detail auf dem Stapel des Tabs,
/// in dem man ist (`AppTarget.aktuell`).
///
/// **Ein Entwurf öffnet den Editor** (Spec 7.3, Plan 3.8): Er öffnet **nicht**
/// das Detail — ein Entwurf ist weder startbar noch einplanbar.
class GymTrainingKachel extends ConsumerWidget {
  const GymTrainingKachel({
    super.key,
    required this.kachel,
    required this.router,
  });

  final TrainingKachel kachel;
  final AppRouter router;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = kachel.id;
    final seite = ref.watch(gymTrainingsSeiteProvider(id));
    final stile = _Stile(context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final line = CupertinoDynamicColor.resolve(Palette.line, context);
    final iron = CupertinoDynamicColor.resolve(Palette.iron, context);

    // Der **aktuelle** Stand wird gelesen, nicht der des letzten Baus: Zwei
    // Züge oder Aktionen kurz hintereinander drehen zweimal.
    void drehe() {
      final notifier = ref.read(gymTrainingsSeiteProvider(id).notifier);
      notifier.setze(
        ref.read(gymTrainingsSeiteProvider(id)) == MuskelSeite.vorne
            ? MuskelSeite.hinten
            : MuskelSeite.vorne,
      );
    }

    // Ein Entwurf öffnet den Editor, alles andere das Detail.
    final VoidCallback oeffnen = kachel.isDraft
        ? () => oeffneGymEditor(router, GymEditorQuelle.entwurf(id))
        : () => oeffneGymTrainingDetail(router, id);

    final figur = _Figur(
      schluessel: kGymTrainingsFigur(id),
      punkteSchluessel: kGymTrainingsPunkte(id),
      gefaerbt: {for (final m in kachel.muscles) m: iron},
      muskeln: kachel.muscles,
      seite: seite,
      onDrehen: drehe,
    );

    final inhalt = _Rahmen(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          figur,
          const SizedBox(width: 12),
          // Der Trenner: 1 Punkt, ein wenig kürzer als die Figurspalte
          // (`margin: 4px 0`).
          SizedBox(
            width: 1,
            height: _figurSpalte - 8,
            child: ColoredBox(color: line),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ExcludeSemantics(
              child: _Text(kachel: kachel, stile: stile, muted: muted),
            ),
          ),
          const SizedBox(width: 8),
          ExcludeSemantics(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  gymTrainingsAnzahl(kachel.exerciseCount),
                  key: kGymTrainingsAnzahl(id),
                  style: stile.anzahl,
                ),
                // „Der Winkel folgt der Tür": Jede Kachel hat eine — das Detail
                // oder, beim Entwurf, den Editor.
                const SizedBox(width: 4),
                Icon(
                  CupertinoIcons.chevron_right,
                  size: 13,
                  color: muted.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Semantics(
        key: kGymTrainingsKachel(id),
        container: true,
        button: true,
        label: gymTrainingsKachelVorlesetext(kachel),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: oeffnen,
          child: inhalt,
        ),
      ),
    );
  }
}

/// Name, Dauer und die reservierte Tag-Zeile.
class _Text extends StatelessWidget {
  const _Text({required this.kachel, required this.stile, required this.muted});

  final TrainingKachel kachel;
  final _Stile stile;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final id = kachel.id;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          gymTrainingsKachelName(kachel),
          key: kGymTrainingsName(id),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: stile.name,
        ),
        const SizedBox(height: 2),
        Text(
          gymTrainingsDauer(kachel),
          key: kGymTrainingsDauer(id),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: stile.sub,
        ),
        const SizedBox(height: 2),
        // Reserviert, auch ohne Tags und ohne Kapsel (Spec 7.2).
        SizedBox(
          key: kGymTrainingsTags(id),
          height: _tagZeile,
          child: Row(
            children: [
              if (kachel.isDraft)
                _Kapsel(
                  key: kGymTrainingsEntwurf(id),
                  text: 'Entwurf',
                  farbe: muted,
                ),
              for (final tag in kachel.tags)
                Flexible(
                  child: _Kapsel(
                    text: tag,
                    farbe: CupertinoDynamicColor.resolve(Palette.iron, context),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Eine Kapsel der Tag-Zeile (`.ttags i`): 17 Punkt hoch, Text in der Farbe,
/// Grund derselben Farbe mit 14 % Deckkraft.
class _Kapsel extends StatelessWidget {
  const _Kapsel({super.key, required this.text, required this.farbe});

  final String text;
  final Color farbe;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 5),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: farbe.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              height: _tagZeile / 10.5,
              color: farbe,
            ),
          ),
        ),
      ),
    );
  }
}

/// Die Figur mit den zwei Punkten — **die Fläche des Zugs**.
class _Figur extends StatefulWidget {
  const _Figur({
    required this.schluessel,
    required this.punkteSchluessel,
    required this.gefaerbt,
    required this.muskeln,
    required this.seite,
    required this.onDrehen,
  });

  final Key schluessel;
  final Key punkteSchluessel;
  final Map<Muscle, Color> gefaerbt;
  final Set<Muscle> muskeln;
  final MuskelSeite seite;
  final VoidCallback onDrehen;

  @override
  State<_Figur> createState() => _FigurState();
}

class _FigurState extends State<_Figur> {
  /// Die Strecke des laufenden Zugs, waagerecht, mit Vorzeichen.
  double _strecke = 0;

  /// Ob dieser Zug schon gedreht hat — ein Zug dreht **einmal**.
  bool _gedreht = false;

  void _beginn(DragStartDetails _) {
    _strecke = 0;
    _gedreht = false;
  }

  void _zug(DragUpdateDetails d) {
    if (_gedreht) return;
    _strecke += d.delta.dx;
    if (_strecke.abs() >= _dreh) {
      _gedreht = true;
      widget.onDrehen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final line = CupertinoDynamicColor.resolve(Palette.line, context);
    final vorne = widget.seite == MuskelSeite.vorne;

    Widget punkt(bool an) => SizedBox(
      width: _punkteHoehe,
      height: _punkteHoehe,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: an ? muted : line,
          borderRadius: BorderRadius.circular(_punkteHoehe / 2),
        ),
      ),
    );

    return Semantics(
      key: widget.schluessel,
      container: true,
      customSemanticsActions: {
        const CustomSemanticsAction(label: gymTrainingsFigurUmdrehen):
            widget.onDrehen,
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: _beginn,
        onHorizontalDragUpdate: _zug,
        child: SizedBox(
          width: _figurBreite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: _figurHoehe,
                child: MuskelFigur(
                  gefaerbt: widget.gefaerbt,
                  seite: widget.seite,
                  semantik: gymTrainingsFigurVorlesetext(
                    widget.muskeln,
                    widget.seite,
                  ),
                ),
              ),
              const SizedBox(height: _figurAbstand),
              Row(
                key: widget.punkteSchluessel,
                mainAxisSize: MainAxisSize.min,
                children: [
                  punkt(vorne),
                  const SizedBox(width: 3),
                  punkt(!vorne),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Die graue Kachel — **je Gruppe genau eine**, solange nichts gelesen wurde
/// (Spec 7.4). **Dieselbe Form in Grau**: dieselbe Fläche, dieselbe Höhe,
/// dieselbe Breite. Weder Satz noch Zahl noch Fehler.
class GymTrainingKachelLaedt extends StatelessWidget {
  const GymTrainingKachelLaedt({super.key, required this.schluessel});

  /// `gym-trainings-laedt-templates` bzw. `-eigene`.
  final Key schluessel;

  @override
  Widget build(BuildContext context) {
    final stile = _Stile(context);
    final line = CupertinoDynamicColor.resolve(Palette.line, context);
    final grau = line.withValues(alpha: 0.55);

    Widget block(double breite, double hoehe) => SizedBox(
      width: breite,
      height: hoehe,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: grau,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Semantics(
        key: schluessel,
        container: true,
        label: gymTrainingsLaedtVorlesetext,
        excludeSemantics: true,
        child: _Rahmen(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Die Figurspalte: dieselbe Größe, die Figur als graue Fläche.
              SizedBox(
                width: _figurBreite,
                height: _figurSpalte,
                child: Center(child: block(_figurBreite - 8, _figurHoehe)),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 1,
                height: _figurSpalte - 8,
                child: ColoredBox(color: line),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Die Beispieltexte werden nie gezeichnet, nur gemessen.
                    Platzhalter(beispiel: 'Push — Brust', stil: stile.name),
                    const SizedBox(height: 2),
                    Platzhalter(beispiel: 'ca. 70 min', stil: stile.sub),
                    const SizedBox(height: 2),
                    const SizedBox(height: _tagZeile),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Platzhalter(beispiel: '7 Übungen', stil: stile.anzahl),
              const SizedBox(width: 17),
            ],
          ),
        ),
      ),
    );
  }
}
