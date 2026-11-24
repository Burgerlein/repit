// Die beiden klebenden Leisten der Erfassung (#78): oben der Fortschritt
// unter der Navigationsleiste, unten die Hauptaktion über der Tableiste —
// `subbar` und `bottomBar` aus `docs/screens/components.js`. Beim Training
// scrollt man weit; beides muss von überall erreichbar bleiben.
//
// **Zwei Leisten, kein Glas:** Sie stehen neben scrollendem Inhalt, und
// Glas gehört nur in Tab-Leiste, Nav-Leiste und Fokus-Karten
// (`CLAUDE.md`).
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../design/palette.dart';
import '../design/platzhalter.dart';
import '../design/symbole.dart';
import '../design/typografie.dart';
import 'gym_log_ansicht.dart';
import 'gym_log_provider.dart';
import 'gym_log_schluessel.dart';
import 'gym_log_texte.dart';

/// Der Streifen, auf dem die Leisten liegen: opak, mit einer Haarlinie zur
/// Seite des Inhalts.
class _Streifen extends StatelessWidget {
  const _Streifen({required this.oben, required this.child, this.padding});

  /// `true`: Die Linie liegt unten (Fortschritt); sonst oben (Aktionen).
  final bool oben;
  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final linie = CupertinoDynamicColor.resolve(Palette.line, context);
    final seite = BorderSide(color: linie, width: 0.5);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CupertinoDynamicColor.resolve(Palette.bg, context),
        border: oben ? Border(bottom: seite) : Border(top: seite),
      ),
      child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
    );
  }
}

/// Der Balken: Fortschritt in `Palette.iron` auf grauer Spur. Ein Balken
/// bei 0 ist die richtige Antwort auf „noch nichts" — **nicht** auf „noch
/// nicht gelesen": Dann steht nur die Spur ([anteil] `null`).
class GymBalken extends StatelessWidget {
  const GymBalken({super.key, required this.anteil});

  final double? anteil;

  @override
  Widget build(BuildContext context) {
    final spur = CupertinoDynamicColor.resolve(Palette.line, context);
    final iron = CupertinoDynamicColor.resolve(Palette.iron, context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 5,
        child: ColoredBox(
          color: spur,
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: (anteil ?? 0).clamp(0.0, 1.0),
            child: ColoredBox(color: iron),
          ),
        ),
      ),
    );
  }
}

/// „9 / 21 Sätze" mit Balken und dem Haken, sobald zwischengespeichert
/// wurde.
///
/// **Sätze, nicht Übungen** (Tim, 10.11.2026). Beim Laden stehen Zahl und
/// Haken als graue Form bzw. Ladeanzeiger an **derselben Stelle** in
/// derselben Größe (Spec 3.1, 14) — „0 / 21" hieße „nichts getan" und wäre
/// Fehler `01`.
class GymFortschrittsLeiste extends ConsumerWidget {
  const GymFortschrittsLeiste({super.key, required this.workout});

  final TrainingKey workout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fortschritt = ref.watch(gymFortschrittProvider(workout));
    final speichert = ref.watch(
      gymLogProvider(workout).select((s) => s.speichert),
    );
    final gespeichert = ref.watch(
      gymLogProvider(workout).select((s) => s.gespeichertAm != null),
    );
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final stil = Typografie.numeric(
      TypografieGroesse.subheadline,
      gewicht: FontWeight.w400,
    ).copyWith(fontSize: 13.8, color: muted);

    final fertig = fortschritt.fertig;
    final gesamt = fortschritt.gesamt;

    return _Streifen(
      oben: true,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Semantics(
        container: true,
        label: (fertig == null || gesamt == null)
            ? 'Fortschritt wird geladen'
            : gymFortschrittVorlesetext(fertig, gesamt),
        excludeSemantics: true,
        child: Row(
          key: kGymLogFortschritt,
          children: [
            Expanded(child: GymBalken(anteil: fortschritt.anteil)),
            const SizedBox(width: 10),
            if (fertig == null || gesamt == null)
              Platzhalter(beispiel: gymFortschrittText(0, 21), stil: stil)
            else
              Text(gymFortschrittText(fertig, gesamt), style: stil),
            const SizedBox(width: 10),
            _Gespeichert(speichert: speichert, gespeichert: gespeichert),
          ],
        ),
      ),
    );
  }
}

/// Der Haken: **ein Zeichen, kein Satz** („Zwischengespeichert um 09:41"
/// passt dort nicht hin). Während geschrieben wird, kreist an derselben
/// Stelle ein kleiner Ladeanzeiger; steht nichts zu sagen, bleibt der Platz
/// leer.
class _Gespeichert extends StatelessWidget {
  const _Gespeichert({required this.speichert, required this.gespeichert});

  final bool speichert;
  final bool gespeichert;

  static const _groesse = 18.0;

  @override
  Widget build(BuildContext context) {
    final Widget? inhalt;
    if (speichert) {
      inhalt = const CupertinoActivityIndicator(radius: 7);
    } else if (gespeichert) {
      inhalt = Semantics(
        label: gymZwischengespeichertVorlesetext,
        excludeSemantics: true,
        child: Icon(
          Symbole.aufloesen('checkmark'),
          key: kGymLogGespeichert,
          size: 16,
          color: CupertinoDynamicColor.resolve(Palette.ok, context),
        ),
      );
    } else {
      inhalt = null;
    }
    return SizedBox(
      width: _groesse,
      height: _groesse,
      child: Center(child: inhalt),
    );
  }
}

/// „Training abschließen", „Zwischenspeichern" und die Bilanz — die
/// klebende Fußleiste.
///
/// **Abgeblendet, solange kein einziger Satz zählt** (Spec 3.8). Die
/// Bilanz zählt nach derselben Regel, nach der abgelegt wird, und beim
/// Laden steht an ihrer Stelle eine graue Form.
///
/// **Was dem Nutzer gesagt werden muss, steht hier**, über dem Knopf
/// ([GymLogHinweis]): Wer „Training abschließen" drückt und es klappt
/// nicht, schaut auf den Knopf, nicht an den oberen Rand des Schirms.
class GymAktionsLeiste extends ConsumerWidget {
  const GymAktionsLeiste({
    super.key,
    required this.workout,
    required this.onAbschliessen,
    required this.onZwischenspeichern,
  });

  final TrainingKey workout;
  final VoidCallback onAbschliessen;
  final VoidCallback onZwischenspeichern;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bilanz = ref.watch(gymBilanzProvider(workout));
    final laedt = ref.watch(gymLogProvider(workout).select((s) => s.laedt));
    final bereit = ref.watch(
      gymLogProvider(workout).select((s) => s.laufendes == null),
    );
    final hinweis = ref.watch(gymLogProvider(workout).select((s) => s.hinweis));
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final river = CupertinoDynamicColor.resolve(Palette.river, context);
    final warn = CupertinoDynamicColor.resolve(Palette.warn, context);
    final iron = CupertinoDynamicColor.resolve(Palette.iron, context);
    final surface = CupertinoDynamicColor.resolve(Palette.surface, context);

    final kannAbschliessen =
        bilanz != null && bilanz.saetze > 0 && bereit && !laedt;

    final bilanzStil = TextStyle(
      fontSize: 12.2,
      color: muted,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return _Streifen(
      oben: false,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hinweis != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                gymHinweisText(hinweis),
                key: kGymLogHinweis,
                style: TextStyle(fontSize: 13, height: 1.3, color: warn),
              ),
            ),
          Opacity(
            opacity: kannAbschliessen ? 1 : 0.45,
            child: CupertinoButton(
              key: kGymAbschliessen,
              color: iron,
              disabledColor: iron,
              borderRadius: BorderRadius.circular(12),
              padding: const EdgeInsets.symmetric(vertical: 13),
              onPressed: kannAbschliessen ? onAbschliessen : null,
              child: Text(
                gymAbschliessen,
                style: Typografie.numeric(TypografieGroesse.headline)
                    .copyWith(fontSize: 17, color: surface),
              ),
            ),
          ),
          SizedBox(
            height: 34,
            child: Row(
              children: [
                Flexible(
                  child: CupertinoButton(
                    key: kGymZwischenspeichern,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(44, 34),
                    onPressed: laedt ? null : onZwischenspeichern,
                    child: Text(
                      gymZwischenspeichern,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: river,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: KeyedSubtree(
                      key: kGymLogBilanz,
                      child: bilanz == null
                          ? Platzhalter(
                              beispiel: gymBilanzText(0, 0),
                              stil: bilanzStil,
                            )
                          : Text(
                              gymBilanzText(bilanz.saetze, bilanz.volumeKg),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: bilanzStil,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
