// Das Vollbild des Erfassens (#78): dasselbe Training, eine Übung, größer
// gesetzt — `fsHead`, `fsFoot` und `.fs-body` aus
// `docs/screens/screens/gym-log.js`, Dart-Entsprechung von `GymFocusView`
// und `GymFocusPage`. Man liest es mit Abstand zum Telefon.
//
// **Kein zweiter Navigationsstapel** (Spec 4.1): Zwei verschachtelte
// Stapel schließen die gepushte Seite sofort wieder, und das fällt in
// keinem anderen Test auf. Deshalb steht hier **kein** `Navigator`, **kein**
// `CupertinoTabView` und **kein** `CupertinoPageScaffold` mit
// Navigationsleiste, sondern ein eigener Kopf mit Kreuz und ein eigener Fuß.
// Geschoben wird es über `Navigator.of(context, rootNavigator: true)`
// ([oeffneGymVollbild]) — über der Tableiste, nicht in den Stapel des Tabs.
//
// **Kein `Hero`** zwischen Karte und Vollbild: Derselbe Schirm ist aus
// mehreren Tabs erreichbar, und ein Tag, der in zwei Stapeln gleich ist,
// kollidiert (flutter#25218). Ohne `Hero` gibt es nichts, was kollidieren
// könnte.
//
// **Das Vollbild schließt sich selbst mit einem Ergebnis** (Spec 4.4): „Training
// abschließen" schließt das Vollbild und meldet [GymVollbildErgebnis
// .abschliessen]; die Erfassung darunter legt danach ab. Es ruft nie selbst
// `schliesseAb` und poppt nie zwei Routen — zwei Schirme zugleich zu
// schließen geht schief (Swifts `wantsFinish`).
//
// **Die Seite wechselt nie von selbst** (Spec 4.3): Wer den letzten Satz
// einträgt, will als Nächstes vielleicht einen vierten anhängen. Geöffnet
// wird bei der ersten noch nicht erledigten Übung — **außer bei einem frischen
// Training**, dann bei der Aufwärm-Seite (siehe unten).
//
// **Seite 0 ist das Aufwärmen** (Tim, 11.11.2026: „bau bitte cardio auch im
// fullscreen mode ein, dass man das auch auswählen kann"), danach eine Seite
// je Übung. Es ist dieselbe Karte wie in der Erfassung ([GymAufwaermenKarte]
// mit `gross`) und derselbe Entwurf im Notifier: Was hier eingetragen wird,
// steht dort, und umgekehrt. [GymVollbild.start] zählt weiter **Übungen**,
// nicht Seiten — die Seite der Übung `i` ist `i + 1`.
//
// **Bei einem frischen Training öffnet das Vollbild auf der Aufwärm-Seite**
// ([GymLogEntwurf.frisch]: kein Satz, Aufwärmen unbeantwortet). Läge es nur
// eine Wischgeste links vom Sichtbaren, fände man es nicht, wenn man es nicht
// schon kennt. Ist aufgewärmt oder übersprungen, geht es bei der Übung auf,
// die ansteht.
//
// **Unter der Tastatur wird durchgezeichnet statt abgeschnitten**
// (flutter#179482): Nichts hier verkleinert sich um die Tastatur; die
// Seiten bekommen unten stattdessen so viel Rand, wie die Tastatur hoch
// ist, damit man das Feld hochscrollen kann.
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../design/palette.dart';
import '../design/platzhalter.dart';
import '../design/symbole.dart';
import '../design/typografie.dart';
import 'gym_log_ansicht.dart';
import 'gym_log_aufwaermen.dart';
import 'gym_log_bausteine.dart';
import 'gym_log_karte.dart' show GymSatzHinzufuegen;
import 'gym_log_leisten.dart' show GymBalken;
import 'gym_log_pause.dart';
import 'gym_log_provider.dart';
import 'gym_log_satz.dart';
import 'gym_log_schluessel.dart';
import 'gym_log_texte.dart';

/// Wie das Vollbild geschlossen wurde.
enum GymVollbildErgebnis {
  /// Das Kreuz, die Zurück-Geste: Der Zwischenstand ist gespeichert, die
  /// Erfassung bleibt stehen.
  geschlossen,

  /// „Training abschließen" auf der letzten Übung: Die Erfassung legt ab.
  abschliessen,
}

/// Schiebt das Vollbild über den **Wurzel-Navigator** — über die Tableiste.
Future<GymVollbildErgebnis?> oeffneGymVollbild(
  BuildContext context, {
  required TrainingKey workout,
  required int start,
  bool beimAufwaermen = false,
}) => Navigator.of(context, rootNavigator: true).push<GymVollbildErgebnis>(
  CupertinoPageRoute<GymVollbildErgebnis>(
    fullscreenDialog: true,
    builder: (_) => GymVollbild(
      workout: workout,
      start: start,
      beimAufwaermen: beimAufwaermen,
    ),
  ),
);

class GymVollbild extends ConsumerStatefulWidget {
  const GymVollbild({
    super.key,
    required this.workout,
    required this.start,
    this.beimAufwaermen = false,
  });

  final TrainingKey workout;

  /// Der Index der **Übung**, bei der es aufgeht — nicht der Seite: Davor
  /// steht noch die Aufwärm-Seite.
  final int start;

  /// Geht es auf der Aufwärm-Seite auf, statt bei der Übung [start]? Wer das
  /// entscheidet, steht an **einer** Stelle: `_oeffneVollbild` in
  /// `gym_log_view.dart`.
  final bool beimAufwaermen;

  @override
  ConsumerState<GymVollbild> createState() => _GymVollbildState();
}

class _GymVollbildState extends ConsumerState<GymVollbild> {
  /// Die Aufwärm-Seite steht vor Übung 1.
  static const _seitenVorUebungen = 1;

  late final PageController _controller = PageController(
    initialPage: _startSeite,
  );
  late int _seite = _startSeite;

  int get _startSeite =>
      widget.beimAufwaermen ? 0 : widget.start + _seitenVorUebungen;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final workout = widget.workout;
    // Die Übungen kommen aus dem Entwurf (Reihenfolge des Trainings), nicht
    // aus dem Katalog.
    final uebungen = ref.watch(
      gymLogProvider(workout)
          .select((s) => [for (final u in s.entwurf.uebungen) u.id]),
    );
    // Die letzte Seite ist die der letzten Übung; die Aufwärm-Seite ist es
    // nie, auch bei einem Training ohne Übungen nicht abschließbar.
    final letzte = _seite >= uebungen.length;
    final bg = CupertinoDynamicColor.resolve(Palette.bg, context);
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);

    return PopScope(
      // Das Kreuz, die Zurück-Geste und das Abschließen laufen alle über ein
      // Pop — und jedes speichert den Zwischenstand (Spec 4.2).
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          unawaited(
            ref.read(gymLogProvider(workout).notifier).schreibeSofort(),
          );
        }
      },
      child: DefaultTextStyle(
        style: CupertinoTheme.of(context).textTheme.textStyle
            .copyWith(color: ink, decoration: TextDecoration.none),
        child: ColoredBox(
          key: kGymVollbild,
          color: bg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Kopf(workout: workout),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: uebungen.length + _seitenVorUebungen,
                  onPageChanged: (i) => setState(() => _seite = i),
                  itemBuilder: (context, i) => i < _seitenVorUebungen
                      ? _AufwaermSeite(workout: workout)
                      : _Seite(
                          workout: workout,
                          uebungId: uebungen[i - _seitenVorUebungen],
                          nummer: i - _seitenVorUebungen + 1,
                          von: uebungen.length,
                        ),
                ),
              ),
              _Fuss(
                workout: workout,
                letzte: letzte,
                onWeiter: () => _controller.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                ),
                onAbschliessen: () =>
                    Navigator.of(context).pop(GymVollbildErgebnis.abschliessen),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `fsHead`: rundes Kreuz links, Titel in der Mitte, „9 / 21" rechts,
/// darunter derselbe Balken wie in der Erfassung.
class _Kopf extends ConsumerWidget {
  const _Kopf({required this.workout});

  final TrainingKey workout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fortschritt = ref.watch(gymFortschrittProvider(workout));
    final titel = gymTrainingsLabel(
      workout,
      ref.watch(gymLogProvider(workout).select((s) => s.training)),
    );
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final surface = CupertinoDynamicColor.resolve(Palette.surface, context);
    final zaehlerStil = Typografie.numeric(
      TypografieGroesse.subheadline,
      gewicht: FontWeight.w400,
    ).copyWith(fontSize: 14, color: muted);
    final fertig = fortschritt.fertig;
    final gesamt = fortschritt.gesamt;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        MediaQuery.paddingOf(context).top + 10,
        18,
        12,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Semantics(
                button: true,
                label: gymVollbildVerlassenVorlesetext,
                excludeSemantics: true,
                child: CupertinoButton(
                  key: kGymVollbildSchliessen,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size.square(34),
                  onPressed: () =>
                      Navigator.of(context)
                          .pop(GymVollbildErgebnis.geschlossen),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: surface,
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox.square(
                      dimension: 34,
                      child: Icon(
                        Symbole.aufloesen('xmark'),
                        size: 15,
                        color: muted,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  titel,
                  textAlign: TextAlign.center,
                  style: Typografie.numeric(TypografieGroesse.headline)
                      .copyWith(
                        color: CupertinoDynamicColor.resolve(
                          Palette.ink,
                          context,
                        ),
                      ),
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 34),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: (fertig == null || gesamt == null)
                      ? Platzhalter(
                          beispiel: gymFortschrittKurz(0, 21),
                          stil: zaehlerStil,
                        )
                      : Text(
                          gymFortschrittKurz(fertig, gesamt),
                          style: zaehlerStil,
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          GymBalken(anteil: fortschritt.anteil),
        ],
      ),
    );
  }
}

/// Die Seite vor Übung 1: das Aufwärmen, gesetzt wie eine Übung — Zeile
/// darüber, Titel in 32 Punkt, darunter die Karte der Erfassung in ihrer
/// großen Fassung. Die Art wählt man wie dort über das Menü
/// (`kGymAufwaermenArt`); die Zeile ist im Vollbild nur höher.
class _AufwaermSeite extends StatelessWidget {
  const _AufwaermSeite({required this.workout});

  final TrainingKey workout;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        18,
        6,
        18,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            gymAufwaermenKicker,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: muted,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 3, bottom: 14),
            child: Text(
              gymAufwaermenTitel,
              style: Typografie.numeric(
                TypografieGroesse.title,
                gewicht: FontWeight.w600,
              ).copyWith(fontSize: 32, height: 1.1, color: ink),
            ),
          ),
          GymAufwaermenKarte(workout: workout, gross: true),
        ],
      ),
    );
  }
}

/// `fs-body`: eine Übung, größer gesetzt.
class _Seite extends ConsumerWidget {
  const _Seite({
    required this.workout,
    required this.uebungId,
    required this.nummer,
    required this.von,
  });

  final TrainingKey workout;
  final String uebungId;
  final int nummer;
  final int von;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uebung = ref.watch(
      gymUebungProvider((workout: workout, uebungId: uebungId)),
    );
    final notifier = ref.read(gymLogProvider(workout).notifier);
    final katalog = uebung.uebung;
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final numerisch = Typografie.numeric(
      TypografieGroesse.title,
      gewicht: FontWeight.w600,
    );

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        18,
        6,
        18,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            gymUebungKicker(nummer, von),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: muted,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              katalog.name,
              style: numerisch.copyWith(fontSize: 32, height: 1.1, color: ink),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              gymZielzeileVollbild(katalog),
              style: Typografie.numeric(
                TypografieGroesse.title3,
                gewicht: FontWeight.w400,
              ).copyWith(fontSize: 18, color: muted),
            ),
          ),
          GymVorschlagZeile(uebung: uebung, gross: true),
          if (katalog.allowsAssist)
            GymUmschalter(
              uebungId: uebungId,
              unterstuetzt: uebung.unterstuetzt,
              onChanged: (an) => notifier.setzeUnterstuetzung(uebungId, an: an),
            ),
          for (var i = 0; i < uebung.saetze.length; i++)
            GymSatzZeile(
              uebung: uebung,
              index: i,
              gross: true,
              onGewicht: (text) =>
                  notifier.setzeSatz(uebungId, i, gewicht: text),
              onWdh: (text) => notifier.setzeSatz(uebungId, i, wdh: text),
              onEntfernen: () => notifier.entferneSatz(uebungId, i),
            ),
          if (katalog.allowsAssist)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                gymUnterstuetzungHinweis,
                style: TextStyle(fontSize: 13.5, height: 1.35, color: muted),
              ),
            ),
          GymSatzHinzufuegen(
            uebungId: uebungId,
            gross: true,
            onTap: () => notifier.haengeSatzAn(uebungId),
          ),
          // Die Uhr gehört zum Training: Sie steht auf der Seite, die man
          // gerade sieht, und läuft weiter, wenn man blättert.
          GymPauseZeile(uebung: katalog, gross: true),
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(
              katalog.cue,
              style: TextStyle(fontSize: 14.4, color: muted),
            ),
          ),
          GymSoGehts(uebung: katalog, gross: true),
        ],
      ),
    );
  }
}

/// `fsFoot`: „Nächste Übung" und darunter „Wischen geht auch"; auf der
/// letzten Übung „Training abschließen" und „Letzte Übung".
class _Fuss extends ConsumerWidget {
  const _Fuss({
    required this.workout,
    required this.letzte,
    required this.onWeiter,
    required this.onAbschliessen,
  });

  final TrainingKey workout;
  final bool letzte;
  final VoidCallback onWeiter;
  final VoidCallback onAbschliessen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bilanz = ref.watch(gymBilanzProvider(workout));
    final bereit = ref.watch(
      gymLogProvider(workout).select((s) => s.laufendes == null && !s.laedt),
    );
    final iron = CupertinoDynamicColor.resolve(Palette.iron, context);
    final surface = CupertinoDynamicColor.resolve(Palette.surface, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final linie = CupertinoDynamicColor.resolve(Palette.line, context);

    // Abschließen wie in der Erfassung: erst, wenn ein Satz zählt.
    final kann = !letzte || (bilanz != null && bilanz.saetze > 0 && bereit);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: CupertinoDynamicColor.resolve(Palette.bg, context),
        border: Border(top: BorderSide(color: linie, width: 0.5)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          10,
          18,
          8 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Opacity(
              opacity: kann ? 1 : 0.45,
              child: CupertinoButton(
                key: letzte ? kGymVollbildAbschliessen : kGymVollbildWeiter,
                color: iron,
                disabledColor: iron,
                borderRadius: BorderRadius.circular(12),
                padding: const EdgeInsets.symmetric(vertical: 14),
                onPressed: kann ? (letzte ? onAbschliessen : onWeiter) : null,
                child: Text(
                  gymVollbildWeiter(letzte: letzte),
                  style: Typografie.numeric(TypografieGroesse.headline)
                      .copyWith(fontSize: 18, color: surface),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                gymVollbildHinweis(letzte: letzte),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
