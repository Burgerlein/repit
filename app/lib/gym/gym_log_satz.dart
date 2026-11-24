// Die Satzzeile (#78) — `setRow` aus `docs/screens/components.js`: Nummer,
// Gewichtsfeld, Wiederholungsfeld, Trendpfeil, Haken oder Minus.
//
// **Kein Abhaken von Hand** (Tim, 10.11.2026): Stehen die Wiederholungen
// da, gilt der Satz als erledigt und zeigt den Haken; ist er leer, steht an
// derselben Stelle das Minus zum Entfernen. Ein Platz, zwei Lagen — und ein
// dritter, leerer, bei der letzten Zeile einer Übung, die sich nicht
// entfernen lässt. Der Platz bleibt in allen dreien gleich groß.
//
// **Die Platzhalter sind die Werte vom letzten Mal** (Abweichung 3), nur
// ohne Verlauf ein Strich — und **während des Ladens gar keiner**: Ein „–"
// sagt „kein Wert vom letzten Mal", solange nicht nachgesehen ist, weiß das
// niemand (Spec 9.3, Fehler `01`).
//
// **Der Trendpfeil** kommt aus `SetTrends.compare` im Kern; ohne
// Vergleichswert gibt es keinen, und sein Platz bleibt frei, damit die
// Felder nicht springen, sobald einer erscheint.
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart' show TextInputFormatter;
import 'package:trainings_core/trainings_core.dart';

import '../design/palette.dart';
import '../design/symbole.dart';
import '../design/typografie.dart';
import 'gym_log_ansicht.dart';
import 'gym_log_felder.dart';
import 'gym_log_schluessel.dart';
import 'gym_log_texte.dart';

/// Eine Zeile einer Übung.
class GymSatzZeile extends StatelessWidget {
  const GymSatzZeile({
    super.key,
    required this.uebung,
    required this.index,
    required this.onGewicht,
    required this.onWdh,
    required this.onEntfernen,
    this.onAktiv,
    this.gross = false,
  });

  final GymUebung uebung;

  /// Null-basiert; sichtbar ist `index + 1`.
  final int index;

  final ValueChanged<String> onGewicht;
  final ValueChanged<String> onWdh;
  final VoidCallback onEntfernen;
  final VoidCallback? onAktiv;

  /// Das Vollbild setzt dieselbe Zeile größer (`.setrow.lg`).
  final bool gross;

  @override
  Widget build(BuildContext context) {
    final satz = uebung.saetze[index];
    final nummer = index + 1;
    final id = uebung.uebung.id;
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final zeit = uebung.istZeit;

    // „Bekannt" heißt: Entwurf **und** Verlauf sind gelesen. Vorher steht
    // kein Platzhalter, auch kein Strich.
    final platzhalter =
        !uebung.laedt &&
        uebung.verlauf.laedt == false &&
        !uebung.verlauf.fehlgeschlagen;

    final abstand = gross ? 10.0 : 8.0;
    final markGroesse = gross ? 26.0 : 22.0;

    final trend = (satz.zaehlt && !uebung.laedt)
        ? SetTrends.compare(
            weight: satz.gewicht,
            reps: satz.wdh,
            assist: uebung.unterstuetzt,
            previous: satz.vorher,
          )
        : null;

    return Semantics(
      container: true,
      label: gymSatzVorlesetext(nummer, gefuellt: satz.zaehlt),
      child: Padding(
        padding: EdgeInsets.only(top: gross ? 10 : 7),
        child: Row(
          children: [
            SizedBox(
              width: gross ? 20 : 14,
              child: Text(
                '$nummer',
                style: Typografie.numeric(
                  TypografieGroesse.subheadline,
                  gewicht: FontWeight.w400,
                ).copyWith(color: muted, fontSize: gross ? 18 : 14),
              ),
            ),
            SizedBox(width: abstand),
            Expanded(
              child: _FeldMitEinheit(
                feldSchluessel: kGymFeldGewicht(id, nummer),
                platzhalterSchluessel: kGymPlatzhalterGewicht(id, nummer),
                einheitSchluessel: kGymEinheitGewicht(id, nummer),
                wert: satz.gewicht,
                platzhalter: (platzhalter && !zeit)
                    ? gymPlatzhalterGewicht(satz.vorher, zeit: zeit)
                    : null,
                einheit: gymGewichtEinheit(
                  unterstuetzt: uebung.unterstuetzt,
                  zeit: zeit,
                ),
                zeigtEinheit: !zeit,
                gesperrt: uebung.laedt || zeit,
                abgeblendet: zeit,
                tastatur: const TextInputType.numberWithOptions(decimal: true),
                formatierer: [gymDezimalFormat],
                onChanged: onGewicht,
                onAktiv: onAktiv,
                gross: gross,
              ),
            ),
            SizedBox(width: abstand),
            Expanded(
              child: _FeldMitEinheit(
                feldSchluessel: kGymFeldWdh(id, nummer),
                platzhalterSchluessel: kGymPlatzhalterWdh(id, nummer),
                einheitSchluessel: kGymEinheitWdh(id, nummer),
                wert: satz.wdh,
                platzhalter: platzhalter
                    ? gymPlatzhalterWdh(satz.vorher)
                    : null,
                einheit: gymWdhEinheit(zeit: zeit),
                zeigtEinheit: true,
                gesperrt: uebung.laedt,
                abgeblendet: false,
                tastatur: TextInputType.number,
                formatierer: [gymZifferFormat],
                onChanged: onWdh,
                onAktiv: onAktiv,
                gross: gross,
              ),
            ),
            SizedBox(width: abstand),
            _Trend(
              schluessel: kGymTrend(id, nummer),
              trend: trend,
              gross: gross,
            ),
            SizedBox(width: abstand),
            SizedBox(
              width: markGroesse,
              height: markGroesse,
              child: satz.zaehlt
                  ? Icon(
                      Symbole.aufloesen('checkmark'),
                      key: kGymHaken(id, nummer),
                      size: markGroesse - 3,
                      color: CupertinoDynamicColor.resolve(Palette.ok, context),
                    )
                  : (satz.entfernbar
                        ? CupertinoButton(
                            key: kGymMinus(id, nummer),
                            padding: EdgeInsets.zero,
                            minimumSize: Size.square(markGroesse),
                            onPressed: onEntfernen,
                            child: Semantics(
                              label: gymSatzEntfernenVorlesetext(nummer),
                              child: Icon(
                                Symbole.aufloesen('minus.circle'),
                                size: markGroesse - 1,
                                color: muted.withValues(alpha: 0.6),
                              ),
                            ),
                          )
                        : null),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ein Feld mit seiner Einheit, in einer Fläche — `.fld` aus
/// `components.css`.
class _FeldMitEinheit extends StatelessWidget {
  const _FeldMitEinheit({
    required this.feldSchluessel,
    required this.platzhalterSchluessel,
    required this.einheitSchluessel,
    required this.wert,
    required this.platzhalter,
    required this.einheit,
    required this.zeigtEinheit,
    required this.gesperrt,
    required this.abgeblendet,
    required this.tastatur,
    required this.formatierer,
    required this.onChanged,
    required this.onAktiv,
    required this.gross,
  });

  final Key feldSchluessel;
  final Key platzhalterSchluessel;
  final Key einheitSchluessel;
  final String wert;

  /// Der graue Text im leeren Feld, `null` solange keiner stehen darf.
  final String? platzhalter;
  final String einheit;
  final bool zeigtEinheit;
  final bool gesperrt;
  final bool abgeblendet;
  final TextInputType tastatur;
  final List<TextInputFormatter> formatierer;
  final ValueChanged<String> onChanged;
  final VoidCallback? onAktiv;
  final bool gross;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final bg = CupertinoDynamicColor.resolve(Palette.bg, context);
    final line = CupertinoDynamicColor.resolve(Palette.line, context);

    final wertStil = Typografie.numeric(
      TypografieGroesse.headline,
      gewicht: FontWeight.w400,
    ).copyWith(fontSize: gross ? 24 : 18, color: ink);
    final einheitStil = TextStyle(
      fontSize: gross ? 12 : 11,
      fontWeight: FontWeight.w600,
      color: muted,
    );

    final leer = wert.isEmpty;
    final radius = BorderRadius.circular(gross ? 11 : 9);

    final flaeche = DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: radius,
        border: Border.all(color: line.withValues(alpha: 0.6), width: 0.5),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: gross ? 13 : 10,
          vertical: gross ? 11 : 7,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Stack(
                alignment: Alignment.centerRight,
                children: [
                  if (leer && platzhalter != null)
                    IgnorePointer(
                      child: Text(
                        platzhalter!,
                        key: platzhalterSchluessel,
                        style: wertStil.copyWith(color: muted),
                        maxLines: 1,
                      ),
                    ),
                  GymFeld(
                    key: feldSchluessel,
                    wert: wert,
                    onChanged: onChanged,
                    onAktiv: onAktiv,
                    stil: wertStil,
                    tastatur: tastatur,
                    formatierer: formatierer,
                    gesperrt: gesperrt,
                  ),
                ],
              ),
            ),
            SizedBox(
              width: gross ? 34 : 30,
              child: zeigtEinheit
                  ? Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        einheit,
                        key: einheitSchluessel,
                        style: einheitStil,
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
    return abgeblendet ? Opacity(opacity: 0.45, child: flaeche) : flaeche;
  }
}

/// Der Trendpfeil — ▲ grün, ▼ rot, = neutral. **Farbe allein trägt die
/// Aussage nicht:** Das Zeichen tut es.
class _Trend extends StatelessWidget {
  const _Trend({
    required this.schluessel,
    required this.trend,
    required this.gross,
  });

  final Key schluessel;
  final SetTrend? trend;
  final bool gross;

  @override
  Widget build(BuildContext context) {
    final trend = this.trend;
    final breite = gross ? 18.0 : 15.0;
    if (trend == null) return SizedBox(width: breite);
    final (zeichen, farbe, vorlesen) = switch (trend) {
      SetTrend.better => ('▲', Palette.ok, 'besser als letztes Mal'),
      SetTrend.worse => ('▼', Palette.warn, 'schlechter als letztes Mal'),
      SetTrend.same => ('=', Palette.muted, 'wie letztes Mal'),
    };
    return SizedBox(
      width: breite,
      child: Semantics(
        label: vorlesen,
        excludeSemantics: true,
        child: Text(
          zeichen,
          key: schluessel,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: gross ? 16 : 13.6,
            fontWeight: FontWeight.w700,
            color: CupertinoDynamicColor.resolve(farbe, context),
          ),
        ),
      ),
    );
  }
}
