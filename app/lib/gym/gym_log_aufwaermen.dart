// Die Aufwärm-Karte (#40, mit #78) — die erste Karte im Training, **über
// Übung 1**, nach `aufwaermen(zustand)` in `docs/screens/screens/gym-log.js`.
//
// **Kein Dialog davor** (Entscheidung 4 im Entwurf): Ein Fenster zwischen
// „Training starten" und der ersten Übung wird beim dritten Mal
// weggewischt, ohne gelesen zu werden.
//
// **Die drei Zustände dürfen nicht einebnen:** nichts eingetragen,
// übersprungen, ausgefüllt. „Übersprungen" ist eine Antwort, ein leeres
// Feld ist es nicht — in der Ablage stehen `null`, `WarmUpSkipped` und
// `WarmUpDone`, drei verschiedene Dinge.
//
// **Alle drei haben dieselbe Geometrie** („Eine Anzeige, die es gibt, hat
// genau eine Form"): dieselben Zeilen, nur die Füllung ändert sich. Eine
// Karte, die beim Überspringen schrumpft, ließe Übung 1 darunter springen.
// Einzige Ausnahme ist die Strecke bei Mobility — eine Zeile, die es für
// diese Art nicht gibt.
//
// **Die Strecke ist echt nullbar, nie 0** — das stellt
// `GymLogAufwaermen.alsWarmUp` sicher; hier steht nur die Eingabe.
//
// **Ohne Empfehlungszeile und ohne Puls.** Der Entwurf zeichnet über der
// Karte „Empfohlen: 10 min Rad, Zone 1" und sagt selbst, sie komme aus dem
// Plan — den es noch nicht gibt (#64, #81); eine Zeile, die eine Zahl
// erfindet, gibt es nicht. Zone und Puls kommen mit dem Zuordnen der
// Health-Workouts (#414).
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart' show TextInputFormatter, TextInputType;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../design/karten_flaeche.dart';
import '../design/palette.dart';
import '../design/section_header.dart';
import 'gym_log_entwurf.dart';
import 'gym_log_felder.dart';
import 'gym_log_provider.dart';
import 'gym_log_schluessel.dart';
import 'gym_log_texte.dart';

/// Der Zustand, den die Karte zeigt — ein Wert mit Gleichheit, damit sie
/// nur neu baut, wenn sich am Aufwärmen etwas ändert.
typedef _Ansicht = ({GymLogAufwaermen aufwaermen, bool laedt});

class GymAufwaermenKarte extends ConsumerWidget {
  const GymAufwaermenKarte({
    super.key,
    required this.workout,
    this.gross = false,
  });

  final TrainingKey workout;

  /// Die Fassung für das Vollbild (#78): größere Zeilen und Schrift, **ohne**
  /// eigene Überschrift und ohne eigenen Seitenrand — beides stellt die Seite
  /// des Vollbilds. Sonst dieselbe Karte, derselbe Zustand, dieselben
  /// Schlüssel: Es gibt eine Karte, nicht zwei.
  final bool gross;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final _Ansicht ansicht = ref.watch(
      gymLogProvider(workout)
          .select((s) => (aufwaermen: s.entwurf.aufwaermen, laedt: s.laedt)),
    );
    final aw = ansicht.aufwaermen;
    final notifier = ref.read(gymLogProvider(workout).notifier);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final river = CupertinoDynamicColor.resolve(Palette.river, context);

    // Gesperrt, solange gelesen wird und solange „übersprungen" gilt — die
    // Felder stehen dann da, dimmed, und behalten ihren Text für den Weg
    // zurück.
    final gesperrt = ansicht.laedt || aw.uebersprungen;
    final ausgefuellt = !aw.leer && !aw.uebersprungen;
    final mobility = aw.art == WarmUpKind.mobility;

    GymLogAufwaermen aktuell() =>
        ref.read(gymLogProvider(workout)).entwurf.aufwaermen;

    return Column(
      key: kGymAufwaermen,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!gross) const SectionHeader(gymAufwaermenTitel),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: gross ? 0 : 20),
          child: DecoratedBox(
            decoration: kartenFlaeche(context),
            child: Column(
              children: [
                _Zeile(
                  gross: gross,
                  abgeblendet: gesperrt,
                  kind: GestureDetector(
                    key: kGymAufwaermenArt,
                    behavior: HitTestBehavior.opaque,
                    onTap: gesperrt
                        ? null
                        : () async {
                            final art = await _waehleArt(context);
                            if (art != null) {
                              notifier.setzeAufwaermen(
                                aktuell().copyWith(art: art),
                              );
                            }
                          },
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            gymAufwaermenArtLabel,
                            style: _textStil(context, gross),
                          ),
                        ),
                        Text(
                          aw.art == null ? '–' : aufwaermArtText(aw.art!),
                          style: TextStyle(
                            fontSize: gross ? 18 : 16,
                            color: muted,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Icon(
                          CupertinoIcons.chevron_down,
                          size: 12,
                          color: muted.withValues(alpha: 0.7),
                        ),
                      ],
                    ),
                  ),
                ),
                _Trenner(),
                _Zeile(
                  gross: gross,
                  abgeblendet: gesperrt,
                  kind: _ZahlZeile(
                    schluessel: kGymAufwaermenMinuten,
                    label: gymAufwaermenMinutenLabel,
                    einheit: gymAufwaermenMinutenEinheit,
                    wert: aw.minuten,
                    gross: gross,
                    gesperrt: gesperrt,
                    tastatur: TextInputType.number,
                    formatierer: [gymZifferFormat],
                    onChanged: (text) => notifier.setzeAufwaermen(
                      aktuell().copyWith(minuten: text),
                    ),
                  ),
                ),
                if (!mobility) ...[
                  _Trenner(),
                  _Zeile(
                    gross: gross,
                    abgeblendet: gesperrt,
                    kind: _ZahlZeile(
                      schluessel: kGymAufwaermenKm,
                      label: gymAufwaermenStreckeLabel,
                      einheit: gymAufwaermenStreckeEinheit,
                      wert: aw.km,
                      gross: gross,
                      gesperrt: gesperrt,
                      tastatur: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      formatierer: [gymDezimalFormat],
                      onChanged: (text) => notifier.setzeAufwaermen(
                        aktuell().copyWith(km: text),
                      ),
                    ),
                  ),
                ],
                _Trenner(),
                // Ein Knopf, drei Lagen: leer → übersprungen → (nochmal)
                // wieder leer; im ausgefüllten Zustand gibt es nichts mehr
                // zu überspringen.
                _Zeile(
                  gross: gross,
                  abgeblendet: ausgefuellt || ansicht.laedt,
                  kind: GestureDetector(
                    key: kGymAufwaermenUeberspringen,
                    behavior: HitTestBehavior.opaque,
                    onTap: (ausgefuellt || ansicht.laedt)
                        ? null
                        : () {
                            final jetzt = aktuell();
                            notifier.setzeAufwaermen(
                              jetzt.copyWith(
                                uebersprungen: !jetzt.uebersprungen,
                              ),
                            );
                          },
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        aw.uebersprungen
                            ? gymAufwaermenWiederEintragen
                            : gymAufwaermenUeberspringen,
                        style: TextStyle(
                          fontSize: gross ? 18 : 16,
                          color: river,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(gross ? 0 : 20, 7, gross ? 0 : 20, 0),
          child: Text(
            gymAufwaermenFuss,
            style: TextStyle(
              fontSize: gross ? 13.5 : 12.5,
              height: 1.35,
              color: muted,
            ),
          ),
        ),
      ],
    );
  }

  /// Das Menü der Art — **eine Auswahl, kein Freitext**: Freitext lässt
  /// sich später nicht vergleichen, und vergleichen ist der Zweck.
  Future<WarmUpKind?> _waehleArt(BuildContext context) =>
      showCupertinoModalPopup<WarmUpKind>(
        context: context,
        builder: (blatt) => CupertinoActionSheet(
          title: const Text(gymAufwaermenArtLabel),
          actions: [
            for (final art in WarmUpKind.values)
              CupertinoActionSheetAction(
                key: kGymAufwaermenArtWahl(art),
                onPressed: () => Navigator.pop(blatt, art),
                child: Text(aufwaermArtText(art)),
              ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(blatt),
            child: const Text(gymAufwaermenAbbrechenAuswahl),
          ),
        ),
      );
}

TextStyle _textStil(BuildContext context, bool gross) => TextStyle(
  fontSize: gross ? 18 : 16,
  color: CupertinoDynamicColor.resolve(Palette.ink, context),
);

/// Eine Zeile der Karte — **alle gleich hoch**.
class _Zeile extends StatelessWidget {
  const _Zeile({
    required this.kind,
    required this.abgeblendet,
    required this.gross,
  });

  final Widget kind;
  final bool gross;
  final bool abgeblendet;

  @override
  Widget build(BuildContext context) {
    final inhalt = SizedBox(
      height: gross ? 54 : 46,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Align(alignment: Alignment.centerLeft, child: kind),
      ),
    );
    return abgeblendet ? Opacity(opacity: 0.45, child: inhalt) : inhalt;
  }
}

class _Trenner extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 14),
    child: SizedBox(
      height: 0.5,
      child: ColoredBox(
        color: CupertinoDynamicColor.resolve(Palette.line, context),
      ),
    ),
  );
}

/// Beschriftung links, Zahlenfeld mit Einheit rechts.
class _ZahlZeile extends StatelessWidget {
  const _ZahlZeile({
    required this.schluessel,
    required this.label,
    required this.einheit,
    required this.wert,
    required this.gross,
    required this.gesperrt,
    required this.tastatur,
    required this.formatierer,
    required this.onChanged,
  });

  final Key schluessel;
  final String label;
  final String einheit;
  final String wert;
  final bool gross;
  final bool gesperrt;
  final TextInputType tastatur;
  final List<TextInputFormatter> formatierer;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    return Row(
      children: [
        Expanded(child: Text(label, style: _textStil(context, gross))),
        SizedBox(
          width: gross ? 100 : 90,
          child: GymFeld(
            key: schluessel,
            wert: wert,
            onChanged: onChanged,
            stil: _textStil(context, gross),
            tastatur: tastatur,
            formatierer: formatierer,
            gesperrt: gesperrt,
            // Ein Strich, nicht 0 (Entwurf, Entscheidung 4).
            hinweis: '–',
            hinweisStil: TextStyle(fontSize: gross ? 18 : 16, color: muted),
          ),
        ),
        SizedBox(
          width: 34,
          child: Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Text(
              einheit,
              style: TextStyle(
                fontSize: gross ? 13 : 12,
                fontWeight: FontWeight.w600,
                color: muted,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
