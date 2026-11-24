import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../design/palette.dart';
import 'gym_log_schluessel.dart';
import 'gym_log_texte.dart';
import 'uebungsbild_animation.dart';
import 'uebungsbilder.dart';
import 'uebungsbilder_provider.dart';

/// Das Bewegungsbild einer Übung im aufgeklappten „So geht's" (#38) — ein
/// oder zwei Bilder (Start, Umkehrpunkt) übereinander, das zweite blendet in
/// einer Schleife ein und aus ([UebungsbildAnimation]); darunter die
/// Pflichtangabe der RepDB-Lizenz und, wo nötig, der Hinweis, dass das Bild
/// die Übung nicht genau zeigt.
///
/// **„Gibt es nicht" und „lädt noch" sind hier zwei verschiedene Dinge, und
/// nur eines davon hat einen Platzhalter.**
///
/// - *Gibt es nicht:* `Uebungsbilder.fuer(id)` ist `null`. Der Provider ist
///   synchron (das Asset ist beim Start gelesen), die Antwort also endgültig.
///   Dann baut das Widget **nichts** — kein grauer Kasten, die Anleitung
///   rückt auf. „Die Animation ist Beiwerk, nicht die Quelle."
/// - *Lädt noch:* Die Übung hat ein Bild, die Datei ist noch nicht
///   dekodiert. Der Platz — quadratisch, Ecken 20 — steht ab dem ersten Bild
///   da, und das Bild blendet **in** ihn ein. Der Text darunter verschiebt
///   sich nicht.
///
/// Kein Glas um die Bilder: Sie stehen in Listen, und die Shader-Last ist
/// real (`CLAUDE.md`).
///
/// Die Pflichtangabe steht **unter dem Bild und nie ohne**; sie kommt aus
/// [Uebungsbild.attribution], nicht aus einer zweiten Zeichenkette.
class GymBewegungsbild extends ConsumerWidget {
  const GymBewegungsbild({super.key, required this.uebung, this.gross = false});

  final Exercise uebung;
  final bool gross;

  /// Größte Kantenlänge des Bildes (`ExerciseAnimationView`: 280).
  static const double _hoechstens = 280;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bild = ref.watch(uebungsbilderProvider).fuer(uebung.id);
    if (bild == null) return const SizedBox.shrink();

    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final frames = bild.frames;
    final hinweis = _hinweis(bild);

    final bilder = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _hoechstens),
        child: UebungsbildAnimation(
          start: bild.start,
          ende: bild.peak,
          frameKey: kGymBildFrame(uebung.id, 1),
          endeKey: kGymBildFrame(uebung.id, 2),
          semantik: gymBildVorlesetext(
            uebung.name,
            zweiBilder: frames.length == 2,
          ),
        ),
      ),
    );

    return Padding(
      key: kGymBild(uebung.id),
      padding: const EdgeInsets.only(bottom: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          bilder,
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              bild.attribution,
              key: kGymBildAttribution(uebung.id),
              style: TextStyle(fontSize: gross ? 12 : 11.5, color: muted),
            ),
          ),
          if (hinweis != null)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                hinweis,
                key: kGymBildHinweis(uebung.id),
                style: TextStyle(
                  fontSize: gross ? 13.5 : 12.5,
                  height: 1.35,
                  // Ein ungefähres Bild wird nicht überlesen: volle Farbe,
                  // nicht die Randnotiz-Farbe der Attribution.
                  color: bild.approximate ? ink : muted,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Bei einem ungefähren Bild: der feste Vorspann, dann der Satz der
  /// Zuordnung. Sonst nur der Satz — oder nichts.
  static String? _hinweis(Uebungsbild bild) {
    final satz = bild.note;
    if (!bild.approximate) return satz;
    return satz == null ? gymBildUngefaehr : '$gymBildUngefaehr $satz';
  }
}
