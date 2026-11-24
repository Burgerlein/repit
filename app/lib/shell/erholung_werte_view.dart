// Der Schirm `erholung-werte` (#117) — die vier Werte mit ihrem
// Normalbereich, dreißig Tage Warnsignale und die Schwellen, ab denen ein
// Wert als Signal zählt. Hinter dem mittleren Ring des Erholung-Schirms.
//
// Der Zustand darunter liegt in `erholung_werte_zustand.dart`, die
// einzelnen Abschnitte in `erholung_werte_abschnitte.dart`.
//
// API und Verhalten sind durch `app/test/shell/erholung_werte_view_test.dart`
// verbindlich vorgegeben (siehe dessen Dateikopf) — diese Datei darf die
// Tests ausführen, aber nicht verändern (`CLAUDE.md`, „Wer Tests schreibt,
// schreibt nicht die Implementierung").
//
// Aufbau nach `docs/screens/screens/erholung-werte.js` und
// `docs/superpowers/specs/2026-10-26-erholung-flutter-design.md`,
// Abschnitt 4; Vorlage sind `Sources/Features/Recovery/RecoveryValuesView
// .swift` und `RecoveryStatusCard.swift`.
//
// **Die Tür hängt seit dem 28.10.2026:** Der mittlere Ring des
// Erholung-Schirms führt hierher, über [oeffneErholungWerte].
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/messwert.dart';
import '../design/glas_abstand.dart';
import '../design/hinweisfuss.dart';
import '../design/palette.dart';
import '../design/section_header.dart';
import 'erholung_werte_abschnitte.dart';
import 'erholung_werte_zustand.dart';
import 'erholung_zustand.dart';
import 'router.dart';
import 'ziele.dart';

/// Öffnet `erholung-werte` auf dem Stapel des **aktuell gewählten** Tabs —
/// die eine Stelle, die das weiß.
///
/// `AppTarget.aktuell`, nicht `.detail`: Ein Schirm, der im Menü unter
/// einem bestimmten Tab einsortiert ist, wechselt trotzdem nie dorthin,
/// sonst führte „zurück" in ein Menü, das der Nutzer nie geöffnet hat
/// (`CLAUDE.md`).
///
/// Eine eigene Stelle statt eines `router.open(...)` beim Aufrufer, weil
/// jedes andere Ziel dieses Bereichs eine hat (`oeffneSchlaf`,
/// `oeffneTagschlaf`, `oeffneBelastung`, `oeffneVerlauf`): Dieses eine
/// davon auszunehmen hieße, dieselbe Entscheidung an zwei Orten zu
/// treffen.
void oeffneErholungWerte(AppRouter router) =>
    router.open(AppTarget.aktuell((context) => const ErholungWerteSeite()));

/// Der Rahmen: Gerüst und Navigationsleiste um [ErholungWerteView].
///
/// Den stellt der Gastgeber, nicht der Schirm — wie `ErholungSeite` in
/// `erholung_view.dart`. **Kein eigener `Navigator`:** Diese Ansicht wird
/// auf den Stapel eines Tabs geschoben, der Stapel gehört weiter
/// `RootView`.
class ErholungWerteSeite extends StatelessWidget {
  const ErholungWerteSeite({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoDynamicColor.resolve(Palette.bg, context),
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Erholung heute'),
      ),
      child: const ErholungWerteView(),
    );
  }
}

/// Der Schirm selbst — ohne Gerüst, ohne Leiste, ohne Navigator.
///
/// **Er besorgt seine Daten selbst** ([erholungProvider]): Jeder Schirm ist
/// aus jedem Tab erreichbar, niemand darf sich darauf verlassen, dass eine
/// Übersicht vorher geladen hat.
class ErholungWerteView extends ConsumerWidget {
  const ErholungWerteView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daten = ref.watch(erholungProvider).daten;
    final status = werteStatus(daten);

    // `padding` statt einer äußeren `Padding`: Eine äußere `Padding`
    // verkleinerte den Scroll-Viewport, statt den Inhalt darin einzurücken
    // — dann liefe er nicht mehr sichtbar unter der Leiste durch
    // (`GlasAbstand`-Klassenkommentar).
    return SingleChildScrollView(
      padding: GlasAbstand.of(context) + const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Die Karte steht in **jedem** der vier Zustände von `Messwert`.
          // Eine fehlende Karte hieße gleichzeitig „alles gut", „die Uhr hat
          // nichts aufgezeichnet" und „die App darf nicht lesen" — und der
          // halbe Schirm spränge, sobald sie auftaucht.
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: WerteStatusKarte(
              key: const Key('erholung-werte-karte'),
              status: status,
              onHealthEinstellungen: () => _zeigeHealthHinweis(context),
            ),
          ),

          // Der Erklärsatz gehört zum Balken: Gibt es keinen, erklärt er
          // nichts.
          if (status.werte.any((wert) => wert.balken != null))
            const _Erklaersatz(),

          // Band und Schwellen brauchen Daten. Ohne sie stehen sie **nicht**
          // leer da: Ein Band ohne Tage und eine Schwellenliste voller
          // „kein Median" wären ein Leerstand während des Ladens
          // (`docs/todo/01`).
          if (daten case Bekannt<ErholungDaten>(:final wert)) ...[
            const SectionHeader('Letzte 30 Tage'),
            WerteSignalband(
              key: const Key('erholung-werte-band'),
              tage: wert.schnappschuss.signalHistory,
            ),
            const SectionHeader('Die Schwellen'),
            WerteSchwellen(
              key: const Key('erholung-werte-schwellen'),
              zeilen: schwellenZeilen(wert.schnappschuss.baseline),
            ),
          ],

          // Hier steht der **Ampel-Satz**, nicht die Health-Fußnote: Der
          // Schirm erklärt, ab wann ein Wert als Signal zählt. Der Entwurf
          // wiederholt an dieser Stelle den Apple-Health-Satz — ein
          // bekannter Fehler des Boards.
          const Hinweisfuss(
            'Die Ampel vergleicht Schlaf, HRV, Ruhepuls und Atemfrequenz mit '
            'deinem eigenen Median der letzten 30 Tage. Ab zwei Signalen '
            'heißt es „Körper unter Stress". Grobe Orientierung, keine '
            'medizinische Bewertung — dein Gefühl zählt mit.',
            key: Key('erholung-werte-fuss'),
          ),
        ],
      ),
    );
  }

  /// `app/` hat kein `url_launcher`, also kann dieser Knopf
  /// `x-apple-health://` noch nicht selbst öffnen — derselbe Stand wie auf
  /// dem Erholung-Schirm. Statt stumm zu bleiben sagt er, welchen Weg der
  /// Nutzer von Hand geht.
  void _zeigeHealthHinweis(BuildContext context) {
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Health-Einstellungen'),
        content: const Text(
          'In der Health-App unter „Profil ▸ Apps ▸ Trainings" lässt sich '
          'der Lesezugriff für Schlaf, HRV, Ruhepuls und Atemfrequenz '
          'einschalten.',
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Verstanden'),
          ),
        ],
      ),
    );
  }
}

/// Was die drei Angaben auf dem Balken bedeuten. Wörtlich aus der
/// Swift-Vorlage und dem Entwurf (`ERKLAERUNG`).
class _Erklaersatz extends StatelessWidget {
  const _Erklaersatz();

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 7, 24, 0),
      child: Text(
        'Der grüne Bereich ist der ohne Warnsignal, der Strich darin dein '
        'Median der letzten 30 Tage, die Marke der Wert von heute Nacht.',
        style: TextStyle(fontSize: 12, height: 1.35, color: muted),
      ),
    );
  }
}
