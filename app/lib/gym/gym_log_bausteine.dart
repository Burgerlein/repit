// Die kleinen Bausteine der Übungskarte (#78): Vorschlagszeile, Umschalter
// „Zusatzgewicht | Unterstützung" und das zugeklappte „So geht's" —
// `tipRow`, `seg2` und `disclose` aus `docs/screens/components.js`.
import 'package:flutter/cupertino.dart';
import 'package:trainings_core/trainings_core.dart';

import '../design/palette.dart';
import '../design/platzhalter.dart';
import 'gym_bewegungsbild.dart';
import 'gym_log_ansicht.dart';
import 'gym_log_schluessel.dart';
import 'gym_log_texte.dart';
import 'gym_vorschlag_texte.dart';

/// Die Vorschlagszeile über den Satzzeilen — „Steigern auf 24 kg, Ziel
/// 8–12." mit Zeichen und Ton.
///
/// **Genau zwei Zeilen hoch, in jeder Lage** (Spec 14): Der Satz schwankt
/// zwischen einer und zwei Zeilen, und ohne feste Zeilenzahl wüchse jede
/// Karte, sobald ein Verlauf dazukommt. Solange der Verlauf gelesen wird,
/// stehen an der Stelle zwei graue Formen — **nie** „Erstes Mal", das wäre
/// eine Behauptung über Tims Trainingsverlauf (Spec 9.3).
class GymVorschlagZeile extends StatelessWidget {
  const GymVorschlagZeile({
    super.key,
    required this.uebung,
    this.gross = false,
  });

  final GymUebung uebung;
  final bool gross;

  static const _zeilen = 2;

  @override
  Widget build(BuildContext context) {
    final verlauf = uebung.verlauf;
    final vorschlag = verlauf.vorschlag;
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);

    final Color ton;
    final String zeichen;
    final String? text;
    if (vorschlag == null) {
      ton = muted;
      zeichen = '•';
      text = verlauf.fehlgeschlagen ? gymVerlaufNichtGelesen : null;
    } else {
      final gewaehlt = vorschlagTon(vorschlag, hatVerlauf: verlauf.hatVerlauf);
      ton = gewaehlt == null
          ? muted
          : CupertinoDynamicColor.resolve(gewaehlt, context);
      zeichen = vorschlagSymbol(vorschlag, hatVerlauf: verlauf.hatVerlauf);
      text = vorschlagKompaktText(
        vorschlag,
        uebung.uebung,
        hatVerlauf: verlauf.hatVerlauf,
      );
    }

    final stil = TextStyle(fontSize: gross ? 15.7 : 14.4, color: ton);
    final Widget inhalt;
    if (text == null) {
      // Zwei Formen, in der Höhe von zwei Zeilen. Kurze Beispieltexte:
      // `Platzhalter` misst ohne Breitenbegrenzung, und ein langer
      // Beispielsatz liefe aus der Zeile.
      inhalt = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Platzhalter(beispiel: 'Steigern auf 62,5 kg', stil: stil),
          Platzhalter(beispiel: 'Ziel 8 Wiederholungen', stil: stil),
        ],
      );
    } else {
      inhalt = Text(
        text,
        style: stil,
        maxLines: _zeilen,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Padding(
      padding: EdgeInsets.only(top: gross ? 14 : 9),
      child: DecoratedBox(
        key: kGymVorschlag(uebung.uebung.id),
        decoration: BoxDecoration(
          color: ton.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(gross ? 11 : 9),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: gross ? 13 : 10,
            vertical: gross ? 10 : 7,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(zeichen, style: stil.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(width: 7),
              Expanded(
                child: FesteZeilen(zeilen: _zeilen, stil: stil, child: inhalt),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Der Umschalter „Zusatzgewicht | Unterstützung" — **an der Übung, nicht
/// am Training**, und nur bei [Exercise.allowsAssist] (Spec 3.4).
class GymUmschalter extends StatelessWidget {
  const GymUmschalter({
    super.key,
    required this.uebungId,
    required this.unterstuetzt,
    required this.onChanged,
  });

  final String uebungId;
  final bool unterstuetzt;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final line = CupertinoDynamicColor.resolve(Palette.line, context);
    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: DecoratedBox(
        key: kGymUmschalter(uebungId),
        decoration: BoxDecoration(
          color: line.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Row(
            children: [
              Expanded(
                child: _Haelfte(
                  key: kGymUmschalterZusatz(uebungId),
                  text: gymZusatzgewicht,
                  an: !unterstuetzt,
                  onTap: () => onChanged(false),
                ),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: _Haelfte(
                  key: kGymUmschalterUnterstuetzung(uebungId),
                  text: gymUnterstuetzung,
                  an: unterstuetzt,
                  onTap: () => onChanged(true),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Haelfte extends StatelessWidget {
  const _Haelfte({
    super.key,
    required this.text,
    required this.an,
    required this.onTap,
  });

  final String text;
  final bool an;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final surface = CupertinoDynamicColor.resolve(Palette.surface, context);
    return Semantics(
      button: true,
      selected: an,
      label: text,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: an ? surface : null,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.4,
                fontWeight: FontWeight.w500,
                color: an ? ink : muted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// „So geht's" — zugeklappt, denn man kennt die Übung meistens (Spec 5).
/// Aufgeklappt: die Schritte, der häufigste Fehler — **nur wenn die Übung
/// einen hat** (`commonMistake == null` bei den Erzeugten, es wird keiner
/// erfunden) — und darunter die Tipps, je Zeile mit „Tipp: " (#551,
/// Spec 9.7). Alles aus der Bibliothek (`Exercise.howTo`,
/// `Exercise.commonMistake`, `Exercise.tips`), deutsch.
///
/// Die **geschlossene** Anzeige bleibt unverändert — die Hausregel „eine
/// Form" betrifft sie; der Block ändert beim Aufklappen seine Höhe ohnehin.
///
/// Oben im aufgeklappten Block steht das Bewegungsbild
/// ([GymBewegungsbild], #38), wenn die Übung eines hat; **ohne Bild rückt die
/// Anleitung auf** und ist vollständig. Die Attributionszeile der RepDB-Lizenz
/// steht unter dem Bild und nie ohne.
///
/// **Ohne Video-Zeile.** Die Video-Suche auf YouTube braucht ein Paket, das
/// die Adresse öffnet (`url_launcher`), und das ist nicht entschieden — eine
/// Zeile, die tippbar aussieht und schweigt, gibt es nicht.
class GymSoGehts extends StatefulWidget {
  const GymSoGehts({super.key, required this.uebung, this.gross = false});

  final Exercise uebung;
  final bool gross;

  @override
  State<GymSoGehts> createState() => _GymSoGehtsState();
}

class _GymSoGehtsState extends State<GymSoGehts> {
  bool _offen = false;

  @override
  Widget build(BuildContext context) {
    final river = CupertinoDynamicColor.resolve(Palette.river, context);
    final warn = CupertinoDynamicColor.resolve(Palette.warn, context);
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final uebung = widget.uebung;
    final schrift = widget.gross ? 15.5 : 14.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          expanded: _offen,
          child: GestureDetector(
            key: kGymSoGehts(uebung.id),
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _offen = !_offen),
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  Icon(
                    _offen
                        ? CupertinoIcons.chevron_down
                        : CupertinoIcons.chevron_right,
                    size: 11,
                    color: river,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    gymSoGehts,
                    style: TextStyle(fontSize: 14, color: river),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_offen)
          Padding(
            padding: const EdgeInsets.only(top: 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GymBewegungsbild(uebung: uebung, gross: widget.gross),
                for (var i = 0; i < uebung.howTo.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 20,
                          child: Text(
                            '${i + 1}.',
                            style: TextStyle(fontSize: schrift, color: ink),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            uebung.howTo[i],
                            style: TextStyle(
                              fontSize: schrift,
                              height: 1.4,
                              color: ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (uebung.commonMistake != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      gymHaeufigerFehler(uebung.commonMistake!),
                      style: TextStyle(fontSize: schrift - 0.2, color: warn),
                    ),
                  ),
                // Die Tipps stehen darunter, je Zeile eine (#551, Spec 9.7).
                // Ohne `tips` steht hier nichts — leer heißt leer.
                for (final tipp in uebung.tips)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      gymTipp(tipp),
                      style: TextStyle(
                        fontSize: schrift - 0.2,
                        height: 1.4,
                        color: ink,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
