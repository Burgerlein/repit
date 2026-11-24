// Die Fußzeile der Gym-Fokus-Karte (#77) — die vier Formen, die sie
// annehmen kann, und die Übungsvorschau des geplanten Workouts.
// Dart-Entsprechung von `FocusFooter` (`Sources/DesignSystem/FocusCard.swift`)
// und `GymPlanPreview` (`Sources/Features/Gym/GymPlanPreview.swift`),
// gezeichnet nach `gym.js` (`row(...)`, `previewRow`, `previewMore`).
//
// **Die Sätze stehen hier nicht.** Sie kommen aus `gym_fokus_texte.dart` und
// `gym_vorschlag_texte.dart` — genau eine Stelle je Vokabular (Spec
// Abschnitt 4).
//
// **Keine Tür, solange es keine gibt.** Jede Zeile hier führte in Swift ins
// Erfassen (#78) oder in den Lese-Schirm (#107); beides gibt es im Neubau
// nicht. Die Zeilen stehen deshalb ohne `onTap` und ohne Winkel da, die
// Vorschau-Schlusszeile abgeblendet — „der Winkel folgt der Tür"
// (Spec Abschnitt 11).
import 'package:flutter/cupertino.dart';
import 'package:trainings_core/trainings_core.dart';

import '../design/icon_row.dart';
import '../design/palette.dart';
import '../design/typografie.dart';
import 'gym_fokus_texte.dart';
import 'gym_vorschlag_texte.dart';

/// Wie weit die Fußzeile zusätzlich eingerückt wird, damit ihr Inhalt auf
/// der Fluchtlinie des Kartentexts sitzt: [IconRow] rückt selbst um 14 ein,
/// die Karte um 22 (`.card.focus .foot .row { padding-left: 22px }`).
const double _fussEinzug = 22 - 14;

/// Die Trennlinie über der Fußzeile (`.card.focus .foot
/// { border-top: .5px }`).
class _FussTrenner extends StatelessWidget {
  const _FussTrenner();

  @override
  Widget build(BuildContext context) => Container(
    height: 0.5,
    color: CupertinoDynamicColor.resolve(Palette.line, context),
  );
}

/// Eine Fußzeile mit Symbolkachel, Titel, Untertitel und optionalem Wert.
///
/// Trägt die drei Fälle „Als Nächstes: …" (`inProgress`), „‹Gym D› ist
/// offen" (`rest`) und „Erste Woche zurück" (`recovery`).
class GymFussZeile extends StatelessWidget {
  const GymFussZeile({
    super.key,
    required this.symbol,
    required this.akzent,
    required this.titel,
    required this.untertitel,
    this.wert,
  });

  final String symbol;
  final Color akzent;
  final String titel;
  final String untertitel;

  /// Das Zielgewicht rechts. **`null`, wenn es keines gibt** — ohne
  /// Verlauf schlägt [Progression] kein Gewicht vor, und „0 kg" wäre
  /// Fehler `01` in neuer Verpackung (Spec Abschnitt 5.1).
  final String? wert;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _FussTrenner(),
        Padding(
          padding: const EdgeInsets.only(left: _fussEinzug),
          child: IconRow(
            symbol: symbol,
            accent: akzent,
            title: titel,
            subtitle: untertitel,
            value: wert,
          ),
        ),
      ],
    );
  }
}

/// Die ersten Übungen des geplanten Workouts mit ihrem Vorschlagsgewicht,
/// darunter „Alle N Übungen ansehen".
///
/// **Drei Zeilen, nicht vier.** Das Board zeichnet drei
/// (`gym.js:105–107`), die Swift-Vorlage nimmt `limit: 4`
/// (`GymPlanPreview.swift:10`). Nach der Rangfolge aus Spec Abschnitt 2
/// gewinnt das Board; die Abweichung steht dort als offene Entscheidung 3,
/// damit sie nicht als Tippfehler durchgeht.
class GymUebungsVorschau extends StatelessWidget {
  const GymUebungsVorschau({
    super.key,
    required this.workout,
    required this.verlauf,
  });

  final Workout workout;

  /// Übungs-ID → Satzlisten, neueste zuerst ([GymTag.verlauf]). Leer,
  /// solange es keine Gym-Ablage gibt (#59, #78).
  final Map<String, List<List<CompletedSet>>> verlauf;

  static const _zeilen = 3;

  @override
  Widget build(BuildContext context) {
    final uebungen = ExerciseCatalog.exercisesFor(workout);
    final gezeigt = uebungen.take(_zeilen).toList(growable: false);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _FussTrenner(),
        for (final uebung in gezeigt)
          _VorschauZeile(
            uebung: uebung,
            saetze: verlauf[uebung.id] ?? const [],
          ),
        // Stehen ohnehin alle Übungen da, führte die Zeile nirgendwohin —
        // und ein Winkel ohne Tür ist genau der Fehler, den
        // `docs/screens/pruefen.mjs` sucht (Spec Abschnitt 5.2).
        if (uebungen.length > gezeigt.length)
          _AlleAnsehen(anzahl: uebungen.length),
      ],
    );
  }
}

/// Eine Zeile: Name, Satz-/Wiederholungsbereich, Zielgewicht.
class _VorschauZeile extends StatelessWidget {
  const _VorschauZeile({required this.uebung, required this.saetze});

  final Exercise uebung;

  /// Die bisherigen Sitzungen dieser Übung, neueste zuerst. **Ein
  /// vorhandener Schlüssel heißt nicht, dass auch Sätze darunter stehen** —
  /// geprüft wird auf „nicht leer", nicht auf „vorhanden"
  /// (`GymPlanPreview.line`).
  final List<List<CompletedSet>> saetze;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final vorschlag = Progression.suggest(uebung, saetze);
    final hatVerlauf = saetze.isNotEmpty;
    final ton = vorschlagTon(vorschlag, hatVerlauf: hatVerlauf);
    final zielgewicht = vorschlagZielgewichtText(vorschlag, uebung);
    final schema = gymSatzSchemaText(uebung);

    return Semantics(
      container: true,
      // **Der Vorlesetext nennt den Zustand, nicht das Zeichen**
      // (`CLAUDE.md`): `vorschlagZielgewichtText` liefert ohne Verlauf
      // „—", und VoiceOver läse daraus „Strich".
      label: hatVerlauf
          ? '${uebung.name}, $schema, $zielgewicht'
          : '${uebung.name}, $schema, noch kein Zielgewicht',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 19, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                uebung.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: ink),
              ),
            ),
            const SizedBox(width: 9),
            Text(schema, style: TextStyle(fontSize: 12, color: muted)),
            const SizedBox(width: 9),
            Text(
              zielgewicht,
              style:
                  Typografie.tabularNumbers(
                    Typografie.numeric(
                      TypografieGroesse.callout,
                      gewicht: FontWeight.w600,
                    ),
                  ).copyWith(
                    color: ton == null
                        ? ink
                        : CupertinoDynamicColor.resolve(ton, context),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// „Alle 7 Übungen ansehen" — **abgeblendet und ohne Wirkung**, solange der
/// Lese-Schirm des Workouts fehlt (#107). Die Beschriftung bleibt stehen:
/// Ein unbeschrifteter Nicht-Knopf wäre schlimmer als ein abgeblendeter
/// (Spec Abschnitt 11).
class _AlleAnsehen extends StatelessWidget {
  const _AlleAnsehen({required this.anzahl});

  final int anzahl;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.45,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 5, 19, 12),
        child: Text(
          gymAlleUebungenText(anzahl),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: CupertinoDynamicColor.resolve(Palette.river, context),
          ),
        ),
      ),
    );
  }
}
