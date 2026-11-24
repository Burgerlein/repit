// Der Schirm „Letzte Trainings" (#79) — Dart-Entsprechung von
// `GymHistoryView.swift`, gebaut nach dem Entwurf
// `docs/screens/screens/gym-history.js` und der Spec
// `docs/superpowers/specs/` (Datei `…-gym-verlauf-design.md`, im Folgenden
// „die Spec").
//
// API und Verhalten sind durch `app/test/gym/gym_verlauf_*_test.dart`
// verbindlich vorgegeben — diese Dateien dürfen die Tests ausführen, aber
// nicht verändern (`CLAUDE.md`, „Wer Tests schreibt, schreibt nicht die
// Implementierung").
//
// **Drei Abschnitte, und jeder steht in jeder Datenlage** (Spec 3): die
// Kennzahlen, genau eines von vier — Karten, „noch nichts da", „nicht lesbar"
// oder eine graue Kartenzeile —, und der Hinweis am Fuß. Keiner verschwindet,
// weil ein Wert fehlt (`CLAUDE.md`: „Eine Anzeige, die es gibt, hat genau
// eine Form").
//
// **Der Puls** (#512) steht in jeder offenen Karte, in jedem der vier
// Zustände (`gym_puls_block.dart`). Das Übungsband steht nur, wo Satz-
// Uhrzeiten einen Abschnitt ergeben haben; sonst steht ein Satz, warum.
// **Der Dialog der Health-Freigabe wird hier ausgelöst**, nicht im
// Lade-Provider: Der Verlauf ist aus jedem Tab erreichbar und darf sich nicht
// darauf verlassen, dass Heute vorher geöffnet war (#183).
//
// **Kein Navigator hier.** Der Schirm wird auf den Stapel des Tabs
// geschoben, aus dem man kommt ([oeffneGymVerlauf], `AppTarget.aktuell`).
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/glas_abstand.dart';
import '../design/hinweisfuss.dart';
import '../design/inset_card.dart';
import '../design/palette.dart';
import '../design/platzhalter.dart';
import '../health/health_provider.dart' show freigabeAnfrageProvider;
import '../shell/mess_abschnitte.dart' show Notizflaeche;
import '../shell/router.dart';
import '../shell/ziele.dart';
import 'gym_letzte_trainings_provider.dart';
import 'gym_verlauf_karte.dart';
import 'gym_verlauf_kennzahlen.dart';
import 'gym_verlauf_schluessel.dart';
import 'gym_verlauf_texte.dart';

/// Öffnet den Verlauf auf dem Stapel des **aktuell gewählten** Tabs —
/// gerufen aus der Zeile „Letzte Trainings" und dem Knopf „Verlauf" des
/// Gym-Schirms.
///
/// `AppTarget.aktuell`, nicht `.detail`: Gepusht wird in den Stapel des
/// Tabs, aus dem man kommt, sonst führte „zurück" in ein Menü, das der
/// Nutzer nie geöffnet hat (`CLAUDE.md`).
void oeffneGymVerlauf(AppRouter router) =>
    router.open(AppTarget.aktuell((_) => const GymVerlaufView()));

/// Der ganze geschobene Schirm — mit Gerüst und Navigationsleiste (Zurück,
/// Titel „Letzte Trainings").
///
/// **Er besorgt seine Daten selbst** ([gymLetzteTrainingsProvider]): Aus
/// jedem Tab direkt erreichbar, darf er sich nicht darauf verlassen, dass
/// die Gym-Übersicht vorher geladen hat. Hereingereicht wird nichts.
class GymVerlaufView extends ConsumerWidget {
  const GymVerlaufView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // **Hier fragt der Verlauf nach der Health-Freigabe** (#183, #512) — der
    // Puls braucht sie, und ohne sie liefert Apple eine leere Antwort ohne
    // Fehler. Beobachtet, nicht gelesen: ein reiner Lesezugriff löst keinen
    // Dialog aus. Der Provider hält sein Ergebnis, also fragt der Schirm
    // höchstens einmal je Sitzung der App, gleich wie oft er geöffnet wird.
    ref.watch(freigabeAnfrageProvider);

    final stand = ref.watch(gymLetzteTrainingsProvider);

    return CupertinoPageScaffold(
      backgroundColor: CupertinoDynamicColor.resolve(Palette.bg, context),
      navigationBar: const CupertinoNavigationBar(
        middle: Text(gymVerlaufTitel),
      ),
      child: SingleChildScrollView(
        padding: GlasAbstand.of(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GymVerlaufKennzahlen(stand: stand),
            ..._verlauf(stand),
            const Hinweisfuss(gymVerlaufFuss, key: kGymVerlaufHinweis),
          ],
        ),
      ),
    );
  }

  /// **Genau eines von vieren** (Spec 3, 6).
  List<Widget> _verlauf(GymLetzteTrainings stand) {
    if (stand.laedt) return const [_KartenLaedt()];
    if (stand.fehlgeschlagen) {
      return const [
        Notizflaeche(
          key: kGymVerlaufFehler,
          text: gymVerlaufFehlerText,
          ton: Palette.warn,
          oben: 10,
        ),
      ];
    }
    if (stand.karten.isEmpty) {
      return const [
        Notizflaeche(key: kGymVerlaufLeer, text: gymVerlaufLeerText, oben: 10),
      ];
    }
    final neueste = stand.karten.first.id;
    return [
      for (final sitzung in stand.karten)
        gymVerlaufKarte(sitzung, anfangsOffen: sitzung.id == neueste),
    ];
  }
}

/// Die graue Kartenzeile — **nur**, solange nichts bekannt ist. Wie viele
/// Karten es werden, weiß niemand; die eine Zeile hält den Platz, in Höhe
/// und Breite einer zugeklappten Karte.
class _KartenLaedt extends StatelessWidget {
  const _KartenLaedt();

  @override
  Widget build(BuildContext context) {
    const titel = TextStyle(fontSize: 15, fontWeight: FontWeight.w600);
    const hinweis = TextStyle(fontSize: 13);

    return Padding(
      key: kGymVerlaufKartenLaedt,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: InsetCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          child: Row(
            children: [
              // `Flexible`: Die graue Form nimmt das Maß ihres
              // Beispieltexts und darf in einer schmalen Zeile nicht über
              // den Rand laufen.
              Flexible(
                child: Platzhalter(beispiel: 'Gym A · Do. 05.03.', stil: titel),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Platzhalter(
                    beispiel: '18 Sätze · 7.240 kg · 68 min',
                    stil: hinweis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
