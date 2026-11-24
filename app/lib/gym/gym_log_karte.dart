// Die Übungskarte der Erfassung (#78) — `excCard` aus
// `docs/screens/components.js`, Dart-Entsprechung von
// `GymLogExerciseCard.swift`.
//
// **Erledigte Übungen klappen zu einer Zeile zu**, damit der Schirm im
// Verlauf des Trainings kürzer wird statt länger (Spec 3.4) — aber **erst
// beim Weitertippen**, nicht sobald der letzte Satz steht (Tim,
// 10.11.2026): „12" gilt schon nach der „1" als vollständig, und eine Karte,
// die dann zuklappt, verschwindet mitten in der Eingabe. Zuklappen und
// Aufklappen von Hand geht nur bei erledigten Übungen; eine halb gefüllte
// Karte bleibt offen (Swift: `header` ist `.disabled(!isComplete)`).
//
// **Die Karte hängt allein an ihrer Übung** ([gymUebungProvider]): Tippen
// in Übung 3 baut Übung 5 nicht neu, und der Takt der Pausenuhr zeichnet
// nur die Pausenzeile (Hausregel 2, Fehler `03`).
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../design/karten_flaeche.dart';
import '../design/palette.dart';
import '../design/symbole.dart';
import '../design/typografie.dart';
import 'gym_log_ansicht.dart';
import 'gym_log_entwurf.dart' show gymUebernommenesGewicht;
import 'gym_log_bausteine.dart';
import 'gym_log_pause.dart';
import 'gym_log_provider.dart';
import 'gym_log_satz.dart';
import 'gym_log_schluessel.dart';
import 'gym_log_texte.dart';

/// Welche Karten zugeklappt sind — **ein Wissen für alle Karten**, denn
/// „erst beim Weitertippen" heißt: sobald in einer **anderen** Übung
/// getippt wird.
class GymKartenAnsicht extends ChangeNotifier {
  String? _zuletzt;
  final Map<String, bool> _vonHand = {};

  /// In dieser Übung wurde zuletzt getippt.
  void aktiv(String uebungId) {
    if (_zuletzt == uebungId) return;
    _zuletzt = uebungId;
    notifyListeners();
  }

  /// Ob die Karte zugeklappt steht. Eine unfertige nie.
  ///
  /// Von Hand Gewähltes gilt vor allem anderen. Sonst klappt eine erledigte
  /// Karte zu, sobald **eine andere** angefasst wurde — und, solange noch
  /// nichts angefasst wurde (ein gelesener Zwischenstand), sofort: Ein
  /// wiedergeöffnetes Training soll kurz sein, nicht lang.
  bool zugeklappt(String uebungId, {required bool erledigt}) {
    if (!erledigt) return false;
    return _vonHand[uebungId] ?? (_zuletzt != uebungId);
  }

  void umschalten(String uebungId, {required bool erledigt}) {
    if (!erledigt) return;
    _vonHand[uebungId] = !zugeklappt(uebungId, erledigt: erledigt);
    notifyListeners();
  }
}

/// Eine Übung als Karte.
class GymUebungKarte extends ConsumerWidget {
  const GymUebungKarte({
    super.key,
    required this.workout,
    required this.uebungId,
    required this.nummer,
    required this.aktuell,
    required this.ansicht,
  });

  final TrainingKey workout;
  final String uebungId;

  /// Die Nummer in der Reihenfolge des Workouts, ab 1.
  final int nummer;

  /// Hier steht die Pausenzeile: die erste noch nicht erledigte Übung.
  final bool aktuell;

  final GymKartenAnsicht ansicht;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uebung = ref.watch(
      gymUebungProvider((workout: workout, uebungId: uebungId)),
    );
    final notifier = ref.read(gymLogProvider(workout).notifier);

    return ListenableBuilder(
      listenable: ansicht,
      builder: (context, _) {
        final zu = ansicht.zugeklappt(uebungId, erledigt: uebung.erledigt);
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: Opacity(
            opacity: uebung.erledigt ? 0.75 : 1,
            child: DecoratedBox(
              key: kGymUebung(uebungId),
              decoration: kartenFlaeche(context),
              child: Padding(
                padding: const EdgeInsets.all(13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Kopf(
                      uebung: uebung,
                      nummer: nummer,
                      onTap: () => ansicht.umschalten(
                        uebungId,
                        erledigt: uebung.erledigt,
                      ),
                    ),
                    if (zu)
                      _Zusammenfassung(uebung: uebung)
                    else
                      ..._koerper(context, uebung, notifier),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _koerper(
    BuildContext context,
    GymUebung uebung,
    GymLogNotifier notifier,
  ) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final katalog = uebung.uebung;
    return [
      GymVorschlagZeile(uebung: uebung),
      if (katalog.allowsAssist)
        GymUmschalter(
          uebungId: uebungId,
          unterstuetzt: uebung.unterstuetzt,
          onChanged: (an) {
            ansicht.aktiv(uebungId);
            notifier.setzeUnterstuetzung(uebungId, an: an);
          },
        ),
      for (var i = 0; i < uebung.saetze.length; i++)
        GymSatzZeile(
          uebung: uebung,
          index: i,
          onGewicht: (text) => notifier.setzeSatz(uebungId, i, gewicht: text),
          onWdh: (text) => notifier.setzeSatz(uebungId, i, wdh: text),
          onEntfernen: () => notifier.entferneSatz(uebungId, i),
          onAktiv: () => ansicht.aktiv(uebungId),
        ),
      if (katalog.allowsAssist)
        Padding(
          padding: const EdgeInsets.only(top: 9),
          child: Text(
            gymUnterstuetzungHinweis,
            style: TextStyle(fontSize: 12.5, height: 1.35, color: muted),
          ),
        ),
      GymSatzHinzufuegen(
        uebungId: uebungId,
        onTap: () {
          ansicht.aktiv(uebungId);
          notifier.haengeSatzAn(uebungId);
        },
      ),
      if (aktuell) GymPauseZeile(uebung: katalog),
      Padding(
        padding: const EdgeInsets.only(top: 9),
        child: Text(
          katalog.cue,
          style: TextStyle(fontSize: 12.5, color: muted),
        ),
      ),
      GymSoGehts(uebung: katalog),
    ];
  }
}

/// Die Kopfzeile: Nummer, Name, Zielzeile, Kreis bzw. Haken.
class _Kopf extends StatelessWidget {
  const _Kopf({
    required this.uebung,
    required this.nummer,
    required this.onTap,
  });

  final GymUebung uebung;
  final int nummer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final line = CupertinoDynamicColor.resolve(Palette.line, context);
    final ok = CupertinoDynamicColor.resolve(Palette.ok, context);
    final katalog = uebung.uebung;

    return Semantics(
      button: uebung.erledigt,
      child: GestureDetector(
        key: kGymUebungKopf(katalog.id),
        behavior: HitTestBehavior.opaque,
        onTap: uebung.erledigt ? onTap : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 18,
              child: Text(
                '$nummer',
                style: Typografie.numeric(
                  TypografieGroesse.subheadline,
                  gewicht: FontWeight.w400,
                ).copyWith(fontSize: 14, color: muted),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    katalog.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: ink,
                    ),
                  ),
                  Text(
                    gymZielzeile(katalog),
                    style: Typografie.numeric(
                      TypografieGroesse.subheadline,
                      gewicht: FontWeight.w400,
                    ).copyWith(fontSize: 14, color: muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 9),
            SizedBox(
              width: 22,
              height: 22,
              child: Icon(
                Symbole.aufloesen(
                  uebung.erledigt ? 'checkmark.circle.fill' : 'circle',
                ),
                size: 21,
                color: uebung.erledigt ? ok : line,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// „60 kg × 10  ·  62,5 kg × 9  ·  …" — die zugeklappte Karte.
class _Zusammenfassung extends StatelessWidget {
  const _Zusammenfassung({required this.uebung});

  final GymUebung uebung;

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final katalog = uebung.uebung;
    return Padding(
      padding: const EdgeInsets.only(left: 27, top: 5),
      child: Text(
        gymUebungZusammenfassung(katalog, [
          // Die Zusammenfassung nennt, was **abgelegt** wird: ein leeres
          // Gewichtsfeld heißt „wie letztes Mal" (Tim, 10.11.2026).
          for (final s in uebung.saetze)
            RawSet(
              weight:
                  gymUebernommenesGewicht(
                    s.gewicht,
                    s.vorher,
                    zeit: uebung.istZeit,
                  ) ??
                  s.gewicht,
              reps: s.wdh,
            ),
        ], unterstuetzt: uebung.unterstuetzt),
        key: kGymZusammenfassung(katalog.id),
        style: Typografie.numeric(
          TypografieGroesse.subheadline,
          gewicht: FontWeight.w400,
        ).copyWith(fontSize: 14, color: muted),
      ),
    );
  }
}

/// „+ Satz" — hängt eine Zeile an, die das Gewicht der letzten erbt.
class GymSatzHinzufuegen extends StatelessWidget {
  const GymSatzHinzufuegen({
    super.key,
    required this.uebungId,
    required this.onTap,
    this.gross = false,
  });

  final String uebungId;
  final VoidCallback onTap;
  final bool gross;

  @override
  Widget build(BuildContext context) {
    final river = CupertinoDynamicColor.resolve(Palette.river, context);
    final line = CupertinoDynamicColor.resolve(Palette.line, context);
    return Padding(
      padding: EdgeInsets.only(top: gross ? 14 : 9),
      child: GestureDetector(
        key: kGymSatzHinzu(uebungId),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: line, width: 0.5),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: gross ? 11 : 7),
            child: Center(
              child: Text(
                gymSatzHinzufuegen,
                style: TextStyle(
                  fontSize: gross ? 15 : 14,
                  fontWeight: FontWeight.w600,
                  color: river,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
