// Das Blatt hinter dem „?" der Schlaf-Score-Karte (#429, Vorschlag A).
//
// **Hier steht, was bis zum 10.11.2026 als Satz unter der Karte stand**
// (`_maximumSatz`): warum weniger als 100 Punkte erreichbar sind und dass
// der Anteil bewertet wird. Der Satz erschien nur, wenn ein Teil entfiel,
// und machte die Karte dann um drei Zeilen höher — beim Blättern von einer
// gemessenen auf eine eingetragene Nacht sprang alles darunter. Tim hat
// Vorschlag A gewählt: Das „?" steht immer da, die Erklärung dahinter.
// Entwurf: `docs/screens/screens/schlaf.js`, Zustand
// „Fragezeichen geöffnet".
//
// **„Keine medizinische Bewertung" steht hier und unten auf der Seite.**
// Ein Pflichthinweis darf nicht nur hinter einem Fragezeichen stehen
// (Erinnerung „Hilfetexte hinter ein Fragezeichen").
//
// **Ohne „statt 100".** `schlaf_view_test.dart` hält fest, dass bei 70
// erreichbaren Punkten in der Karte nirgends 100 steht; das Blatt nennt
// die erreichbare Summe und die Punkte des entfallenen Teils, nicht die
// Summe, die es nicht gibt.
import 'package:flutter/cupertino.dart';
import 'package:trainings_core/trainings_core.dart' show SleepScore;

import '../design/palette.dart';
import 'schlaf_texte.dart';
import 'schlaf_zustand.dart';

/// Öffnet das Blatt zur Nacht [nacht].
Future<void> zeigeSchlafScoreBlatt(BuildContext context, SchlafNacht nacht) =>
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) =>
          SchlafScoreBlatt(key: const Key('schlaf-score-blatt'), nacht: nacht),
    );

class SchlafScoreBlatt extends StatelessWidget {
  const SchlafScoreBlatt({super.key, required this.nacht});

  final SchlafNacht nacht;

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoDynamicColor.resolve(Palette.bg, context);
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final unten = MediaQuery.of(context).padding.bottom;
    final score = nacht.score;
    final warum = _warum(nacht);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      ),
      padding: EdgeInsets.only(bottom: unten + 20),
      child: DefaultTextStyle(
        style: TextStyle(color: ink, fontSize: 15),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  // Gleich breit wie der Knopf rechts, damit der Titel
                  // mittig steht.
                  const SizedBox(width: 72),
                  Expanded(
                    child: Text(
                      'Schlaf-Score',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: ink,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 72,
                    child: CupertinoButton(
                      key: const Key('schlaf-score-blatt-fertig'),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(44, 36),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Fertig',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (warum != null)
              _Absatz(
                titel: 'Warum sind ${score.maxTotal} Punkte erreichbar?',
                text: warum,
              ),
            _Absatz(
              titel: 'Wie der Score entsteht',
              text:
                  'Dauer bis ${SleepScore.maxDuration} Punkte, Zubettgehzeit '
                  'gegen dein Schlafenszeitziel bis ${SleepScore.maxBedtime}, '
                  'Unterbrechungen bis ${SleepScore.maxInterruptions}. '
                  'Bewertet wird der Anteil der erreichbaren Punkte: ab '
                  '${_prozent(SleepScore.veryGoodShare)} % sehr gut, ab '
                  '${_prozent(SleepScore.goodShare)} % gut, ab '
                  '${_prozent(SleepScore.okayShare)} % okay.',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Text(
                'Eigener Score, eine Schätzung aus Apple-Health-Werten — '
                'keine medizinische Bewertung.',
                style: TextStyle(fontSize: 12, height: 1.4, color: muted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static int _prozent(double anteil) => (anteil * 100).round();

  /// Warum weniger als 100 Punkte erreichbar sind — `null`, wenn alle drei
  /// Teile zählen. **Jeder Grund einzeln**, und am Ende die Rechnung, aus
  /// der die Bewertung kommt: Ohne sie ist „sehr gut" neben 71 Punkten
  /// nicht nachrechenbar.
  static String? _warum(SchlafNacht nacht) {
    final score = nacht.score;
    if (score.maxTotal >= 100) return null;

    final saetze = <String>[
      if (score.interruptions == null)
        'Diese Nacht hast du von Hand eingetragen. Wie oft du wach warst, '
            'hat niemand gezählt — die Unterbrechungen entfallen mitsamt '
            'ihren ${SleepScore.maxInterruptions} Punkten, statt geschätzt '
            'zu werden.',
      if (score.bedtime == null)
        'Für diese Nacht ist keine Einschlafzeit aufgezeichnet — die '
            'Zubettgehzeit entfällt mitsamt ihren ${SleepScore.maxBedtime} '
            'Punkten.',
    ];
    // Ganzzahlig abgerundet: Dieselbe Grenze wie die Bewertung, die mit
    // `>=` vergleicht. Gerundet stünde bei 84,6 % „85 %, also gut" da.
    final prozent = score.total * 100 ~/ score.maxTotal;
    saetze.add(
      '${score.total} von ${score.maxTotal} sind $prozent %, also '
      '„${schlafBewertungText(score.rating)}".',
    );
    return saetze.join(' ');
  }
}

class _Absatz extends StatelessWidget {
  const _Absatz({required this.titel, required this.text});

  final String titel;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titel,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: ink,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            text,
            style: TextStyle(fontSize: 14, height: 1.45, color: muted),
          ),
        ],
      ),
    );
  }
}
