// Die Abschnitte des Trainings-Details (#533 unter #531, Task 2.4; Spec 8.2) —
// `gym-training-detail.js`: Kopf, Figur, Übungen, Eckdaten, Löschen. Eigene
// Datei, damit der Schirm ([GymTrainingDetailView]) lesbar bleibt.
//
// **Jeder Abschnitt hat eine Form, in jeder Lage** (`CLAUDE.md`, Spec 8.3):
// Solange das Training gelesen wird ([GymTrainingDetailStand.laedt]), stehen
// alle da — Titel, Lede, Figur und Zeilen als graue Formen **in derselben
// Höhe**. Nichts davon sagt „nicht gefunden".
//
// **Gerechnet wird hier nichts:** Dauer, Muskeln und Zählungen liegen fertig in
// der [TrainingKachel] des Stands (Fehler `03`).
import 'package:flutter/cupertino.dart';
import 'package:trainings_core/trainings_core.dart';

import '../design/icon_row.dart';
import '../design/inset_card.dart';
import '../design/muskel_figur.dart';
import '../design/palette.dart';
import '../design/platzhalter.dart';
import '../design/section_header.dart';
import '../design/typografie.dart';
import 'gym_trainings_provider.dart';
import 'gym_trainings_schluessel.dart';
import 'gym_trainings_texte.dart';

/// Kicker, Titel und Lede (`obBody`).
///
/// **Titel und Lede haben feste Zeilenzahlen**: Der Name schwankt zwischen einer
/// und zwei Zeilen, ohne reservierte Höhe spränge der Schirm beim Eintreffen.
class GymDetailKopf extends StatelessWidget {
  const GymDetailKopf({super.key, required this.stand});

  final GymTrainingDetailStand stand;

  static const _titelZeilen = 2;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final kachel = stand.kachel;
    final training = stand.training;

    final kickerStil = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.8,
      color: muted,
    );
    final titelStil = Typografie.numeric(TypografieGroesse.title2)
        .copyWith(color: ink);
    final ledeStil = TextStyle(fontSize: 15, height: 1.3, color: muted);

    // Die Beispiele der grauen Formen werden nie gezeichnet, nur gemessen.
    final kicker = training == null
        ? Platzhalter(beispiel: 'Eigenes Training', stil: kickerStil)
        : Text(
            (training.category == WorkoutCategory.template
                    ? gymTrainingDetailKickerTemplate
                    : gymTrainingDetailKickerEigenes)
                .toUpperCase(),
            style: kickerStil,
          );
    final titel = training == null
        ? Platzhalter(beispiel: 'Push — Brust, Schultern', stil: titelStil)
        : Text(
            gymTrainingsKachelName(kachel!),
            maxLines: _titelZeilen,
            overflow: TextOverflow.ellipsis,
            style: titelStil,
          );
    final lede = kachel == null
        ? Platzhalter(
            beispiel: 'ca. 70 min · 6 Übungen · 18 Sätze',
            stil: ledeStil,
          )
        : Text(
            gymTrainingDetailLede(kachel),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ledeStil,
          );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FesteZeilen(zeilen: 1, stil: kickerStil, child: kicker),
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 4),
            child: FesteZeilen(
              zeilen: _titelZeilen,
              stil: titelStil,
              child: titel,
            ),
          ),
          FesteZeilen(zeilen: 1, stil: ledeStil, child: lede),
        ],
      ),
    );
  }
}

/// Die Figur mit **beiden** Seiten (Tim, 19.11.2026), einfarbig in
/// `Palette.iron` — „trifft diese Muskeln", nicht „wie viel" (Spec 8.1).
///
/// Beim Lesen steht dieselbe Figur **ungefärbt** da: die graue Form ist die
/// Figur selbst, in derselben Höhe.
class GymDetailFigur extends StatelessWidget {
  const GymDetailFigur({super.key, required this.stand});

  final GymTrainingDetailStand stand;

  @override
  Widget build(BuildContext context) {
    final iron = CupertinoDynamicColor.resolve(Palette.iron, context);
    final muskeln = stand.kachel?.muscles ?? const <Muscle>{};

    return Padding(
      key: kGymTrainingDetailFigur,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: MuskelFigur(
        gefaerbt: {for (final m in muskeln) m: iron},
        semantik: stand.kachel == null
            ? gymTrainingsLaedtVorlesetext
            : gymTrainingDetailFigurVorlesetext(muskeln),
      ),
    );
  }
}

/// Die Gruppe „Übungen": je Übung eine Zeile, in der Reihenfolge des
/// Trainings — **ohne Gewichte** (Gewichte gehören zur Erfassung, Spec 8.2).
///
/// Eine Übung, die der Katalog nicht kennt, wird **benannt** („Unbekannte
/// Übung (…)", Spec 6.2), nicht erraten und nicht verschwiegen. Beim Lesen
/// steht **eine** graue Zeile: Wie viele es werden, weiß noch niemand.
class GymDetailUebungen extends StatelessWidget {
  const GymDetailUebungen({super.key, required this.stand});

  final GymTrainingDetailStand stand;

  @override
  Widget build(BuildContext context) {
    final linie = CupertinoDynamicColor.resolve(Palette.line, context);
    final training = stand.training;

    final zeilen = training == null
        ? [
            const IconRow(
              symbol: 'dumbbell.fill',
              accent: Palette.iron,
              title: 'Bankdrücken Langhantel',
              subtitle: '4 Sätze · 6–10 Wdh',
              laedt: true,
            ),
          ]
        : _zeilen(training);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(gymTrainingDetailUebungen),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: InsetCard(
            child: Column(
              children: [
                for (var i = 0; i < zeilen.length; i++) ...[
                  if (i > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 56),
                      child: Container(height: 1, color: linie),
                    ),
                  zeilen[i],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _zeilen(WorkoutDefinition training) {
    final gesehen = <String>{};
    return [
      for (final uebung in training.exercises)
        KeyedSubtree(
          // Ein Schlüssel je Übungs-ID; eine doppelte (die Regeln lassen sie
          // nicht zu) bekäme keinen, statt den Aufbau zu sprengen.
          key: gesehen.add(uebung.exerciseId)
              ? kGymTrainingDetailUebung(uebung.exerciseId)
              : null,
          child: _zeile(uebung),
        ),
    ];
  }

  Widget _zeile(WorkoutExercise uebung) {
    final katalog = ExerciseLibrary.byId(uebung.exerciseId);
    return IconRow(
      symbol: 'dumbbell.fill',
      accent: Palette.iron,
      title: katalog?.name ?? 'Unbekannte Übung (${uebung.exerciseId})',
      subtitle: gymTrainingDetailUebungSchema(
        uebung,
        zeit: katalog?.isTimed ?? false,
      ),
    );
  }
}

/// Die Gruppe „Eckdaten": Dauer, Übungen · Sätze, Tags, Herkunft.
///
/// **Herkunft aus der Kategorie abgeleitet, nicht gespeichert** (Spec 17.12).
/// Die Dauer sagt, ob sie **geschätzt** ist (Spec 7.2, 12 Nr. 4): eine
/// Schätzung ist kein Versprechen. Eine fehlende Dauer ist „–", nie `0`.
class GymDetailEckdaten extends StatelessWidget {
  const GymDetailEckdaten({super.key, required this.stand});

  final GymTrainingDetailStand stand;

  @override
  Widget build(BuildContext context) {
    final linie = CupertinoDynamicColor.resolve(Palette.line, context);
    final kachel = stand.kachel;
    final training = stand.training;

    String? dauer;
    String? saetze;
    String? tags;
    String? herkunft;
    if (kachel != null && training != null) {
      final minuten = kachel.minutes;
      dauer = minuten == null
          ? '–'
          : kachel.minutesEntered
          ? 'ca. $minuten min'
          : 'ca. $minuten min · geschätzt';
      saetze = '${kachel.exerciseCount} · ${kachel.setCount}';
      tags = kachel.tags.isEmpty ? '–' : kachel.tags.join(', ');
      herkunft = gymTrainingDetailHerkunft(training.category);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(gymTrainingDetailEckdaten),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: InsetCard(
            child: Column(
              children: [
                _Zeile(
                  schluessel: kGymTrainingDetailDauer,
                  label: 'Dauer',
                  wert: dauer,
                  beispiel: 'ca. 70 min',
                ),
                _Trenner(linie),
                _Zeile(
                  schluessel: kGymTrainingDetailUebungenSaetze,
                  label: gymTrainingDetailUebungenSaetzeLabel,
                  wert: saetze,
                  beispiel: '6 · 18',
                ),
                _Trenner(linie),
                _Zeile(
                  schluessel: kGymTrainingDetailTags,
                  label: 'Tags',
                  wert: tags,
                  beispiel: 'Gym',
                ),
                _Trenner(linie),
                _Zeile(
                  schluessel: kGymTrainingDetailHerkunft,
                  label: 'Herkunft',
                  wert: herkunft,
                  beispiel: 'Template · mit der App',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Trenner extends StatelessWidget {
  const _Trenner(this.farbe);

  final Color farbe;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 14),
    child: Container(height: 1, color: farbe),
  );
}

/// Eine Eckdaten-Zeile (`formRow`): Beschriftung links, Wert rechts.
/// [wert] `null` heißt: noch nicht gelesen — an seiner Stelle steht eine graue
/// Form in der Größe von [beispiel].
class _Zeile extends StatelessWidget {
  const _Zeile({
    required this.schluessel,
    required this.label,
    required this.wert,
    required this.beispiel,
  });

  final Key schluessel;
  final String label;
  final String? wert;
  final String beispiel;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final river = CupertinoDynamicColor.resolve(Palette.river, context);
    final labelStil = TextStyle(fontSize: 15, color: ink);
    final wertStil = TextStyle(fontSize: 15, color: river);
    final wert = this.wert;

    return Padding(
      key: schluessel,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          Text(label, style: labelStil),
          const SizedBox(width: 10),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: wert == null
                  ? Platzhalter(beispiel: beispiel, stil: wertStil)
                  : Text(
                      wert,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: wertStil,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Die Zeile „Training löschen" in Rot, samt Fußtext (`formRow … action weg`,
/// `formFoot`).
///
/// **Nur beim Eigenen** (Spec 26 Nr. 1): Templates sind nicht löschbar, und
/// die Zeile steht auch beim Laden nicht — der Aufrufer baut sie erst, wenn
/// „eigene" gelesen ist.
class GymDetailLoeschen extends StatelessWidget {
  const GymDetailLoeschen({super.key, required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final warn = CupertinoDynamicColor.resolve(Palette.warn, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: InsetCard(
            child: Opacity(
              opacity: onTap == null ? 0.45 : 1,
              child: GestureDetector(
                key: kGymTrainingDetailLoeschen,
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  child: Center(
                    child: Text(
                      gymTrainingDetailLoeschen,
                      style: TextStyle(fontSize: 15, color: warn),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: Text(
            gymTrainingDetailLoeschenFuss,
            style: TextStyle(fontSize: 12.5, height: 1.4, color: muted),
          ),
        ),
      ],
    );
  }
}
