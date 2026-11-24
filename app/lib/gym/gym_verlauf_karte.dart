// Die Aufklappkarte einer Sitzung im Verlauf (#79) — `sectionCard` mit
// `exerciseLog` im Entwurfsboard (`docs/screens/screens/gym-history.js`),
// Variante „Entwurf — Puls mit Übungen" (#512): oben der Pulsblock
// ([GymPulsBlock]), die Übungszeilen tragen — wo Satz-Uhrzeiten einen
// Abschnitt ergeben haben — Ziffer und Ø-Puls.
//
// **Zugeklappt ist eine Karte eine Zeile.** Ihr Inhalt entsteht nicht,
// solange sie zu ist ([KlappAbschnitt.inhalt] ist eine Funktion, kein
// fertiges Widget): Zwölf Karten mit je sieben Übungen und fünfundzwanzig
// Plaketten wären sonst über dreihundert Widgets, von denen eine Handvoll zu
// sehen ist.
//
// **Von oben nach unten** (Spec 7.2, #512): der Pulsblock — in jeder offenen
// Karte, in jedem Zustand —, die Aufwärmzeile — in jeder offenen
// Karte, auch wenn nichts eingetragen ist —, je Übung eine Zeile mit einer
// Plakette je Satz, die Erklärung des „U" (nur, wo ein unterstützter Satz
// steht) und die Notiz (nur, wo es eine gibt).
//
// **Die Reihenfolge der Sätze steht in der Ablage** (`satz_nr`), nie in der
// Satz-Uhrzeit: Diese Datei liest `recordedAt` nirgends — die Abschnitte
// rechnet `GymPulse.sections` im Kern. Eine Sitzung ohne Uhrzeiten — alles
// Übernommene — fällt deshalb nicht heraus, und es steht nirgends eine
// erfundene Zeit.
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../core/messwert.dart';
import '../design/klapp_abschnitt.dart';
import '../design/palette.dart';
import '../design/typografie.dart';
import 'gym_puls_block.dart';
import 'gym_puls_provider.dart';
import 'gym_puls_texte.dart';
import 'gym_verlauf_schluessel.dart';
import 'gym_verlauf_texte.dart';

/// Die Karte einer Sitzung.
///
/// Eine Funktion statt eines eigenen Widgets: Der Schlüssel
/// ([kGymVerlaufKarte]) gehört auf den [KlappAbschnitt] selbst, der den
/// Zustand „offen oder zu" trägt — **ein eigener Schlüssel je Karte**, sonst
/// ordnet Flutter die Zustände nach Stelle zu, und die Stelle verschiebt
/// sich, sobald oben eine Karte dazukommt.
///
/// [anfangsOffen] gilt nur beim ersten Bau: Aufgeklappt bleibt aufgeklappt,
/// auch wenn die Daten darunter sich ändern.
Widget gymVerlaufKarte(ImportedSession sitzung, {required bool anfangsOffen}) {
  final kurz = gymVerlaufKurzfassung(sitzung);
  return KlappAbschnitt(
    key: kGymVerlaufKarte(sitzung.id),
    titel: gymVerlaufKartenTitel(sitzung),
    // `null`, wenn nichts zu sagen ist — nie eine leere Null.
    hinweis: kurz.isEmpty ? null : kurz,
    anfangsOffen: anfangsOffen,
    kopfSchluessel: kGymVerlaufKopf(sitzung.id),
    inhaltSchluessel: kGymVerlaufInhalt(sitzung.id),
    randAbstand: const EdgeInsets.fromLTRB(20, 10, 20, 0),
    inhalt: () => _Inhalt(sitzung: sitzung),
  );
}

class _Inhalt extends ConsumerWidget {
  const _Inhalt({required this.sitzung});

  final ImportedSession sitzung;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // **Gelesen wird nur für geöffnete Karten:** Dieser Inhalt entsteht erst
    // beim Aufklappen, und mit ihm der Leser des Provider (#512).
    final puls = gymPulsAusProvider(ref.watch(gymPulsProvider(sitzung)));
    // Ziffer und Ø gibt es nur, wo der Puls bekannt ist **und** Satz-Uhrzeiten
    // einen Abschnitt ergeben haben (Spec 7).
    final bekannt = puls is Bekannt<GymPuls> ? puls.wert : null;
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final cue = TextStyle(fontSize: 12.5, color: muted);
    final notiz = sitzung.note;
    final mitUnterstuetzung = sitzung.exercises.any(
      (u) => u.sets.any((s) => s.weight < 0),
    );
    // Zwei Zeilen derselben Übung gäbe es nur bei einer fehlerhaften
    // Ablage; der Schlüssel steht trotzdem nur einmal.
    final gesehen = <String>{};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GymPulsBlock(sitzungId: sitzung.id, puls: puls),
        _Aufwaermen(sitzung: sitzung),
        for (var i = 0; i < sitzung.exercises.length; i++)
          _UebungsZeile(
            sitzungId: sitzung.id,
            uebung: sitzung.exercises[i],
            mitSchluessel: gesehen.add(sitzung.exercises[i].exerciseId),
            // Die Position in der Sitzung, ab 1 — nie ein Zähler über die
            // Übungen mit Abschnitt.
            abschnitt: bekannt?.abschnittAn(i + 1),
          ),
        if (mitUnterstuetzung)
          Padding(
            padding: const EdgeInsets.only(top: 9),
            child: Text(gymVerlaufUnterstuetzungHinweis, style: cue),
          ),
        if (notiz != null)
          Padding(
            key: kGymVerlaufNotiz(sitzung.id),
            padding: const EdgeInsets.only(top: 9),
            child: Text(gymVerlaufNotizText(notiz), style: cue),
          ),
      ],
    );
  }
}

/// Die Aufwärmzeile — **drei Zustände** (#40), und sie steht in jeder
/// offenen Karte: Eine Zeile, die nur bei Daten da ist, wäre eine Anzeige,
/// die verschwindet, weil ihr Wert fehlt. Nur ihre Füllung ändert sich.
class _Aufwaermen extends StatelessWidget {
  const _Aufwaermen({required this.sitzung});

  final ImportedSession sitzung;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final line = CupertinoDynamicColor.resolve(Palette.line, context);

    return DecoratedBox(
      key: kGymVerlaufAufwaermen(sitzung.id),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: line, width: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Text(
              'Aufwärmen',
              style: TextStyle(
                fontSize: 14.4,
                fontWeight: FontWeight.w600,
                color: ink,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                gymVerlaufAufwaermenText(sitzung.warmUp),
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 13, color: muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Eine Übung: ihr Name aus dem Katalog, darunter eine Plakette je Satz.
///
/// **Eine Übung, die der Katalog nicht kennt, fällt nicht lautlos heraus**
/// (Spec 8): Die Zeile steht da, mit der Kennung statt des Namens, und ihre
/// Sätze als „Gewicht × Wdh.". Sonst stimmten Kopfzeile und Zeilen nicht
/// mehr zusammen.
class _UebungsZeile extends StatelessWidget {
  const _UebungsZeile({
    required this.sitzungId,
    required this.uebung,
    required this.mitSchluessel,
    required this.abschnitt,
  });

  final String sitzungId;
  final ImportedExercise uebung;
  final bool mitSchluessel;

  /// Der Abschnitt der Übung im Training, oder `null`: dann trägt die Zeile
  /// weder Ziffer noch Ø — und ist trotzdem gleich hoch.
  final GymPulsAbschnitt? abschnitt;

  @override
  Widget build(BuildContext context) {
    final line = CupertinoDynamicColor.resolve(Palette.line, context);
    final katalog = ExerciseLibrary.byId(uebung.exerciseId);

    return DecoratedBox(
      key: mitSchluessel
          ? kGymVerlaufUebung(sitzungId, uebung.exerciseId)
          : null,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: line, width: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _NameZeile(
              sitzungId: sitzungId,
              uebungId: uebung.exerciseId,
              name: katalog?.name ?? uebung.exerciseId,
              abschnitt: abschnitt,
              mitSchluessel: mitSchluessel,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Wrap(
                spacing: 5,
                runSpacing: 5,
                children: [
                  for (var i = 0; i < uebung.sets.length; i++)
                    _Plakette(
                      schluessel: mitSchluessel
                          ? kGymVerlaufSatz(sitzungId, uebung.exerciseId, i + 1)
                          : null,
                      nummer: i + 1,
                      text: gymVerlaufSatzText(katalog, uebung.sets[i]),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Die Zeile mit dem Namen der Übung: links die **Ziffer** des Abschnitts,
/// rechts das **Ø** — beides nur, wo es einen Abschnitt gibt (#512).
///
/// **Dieselbe Höhe mit und ohne** (`CLAUDE.md`, „eine Form"): Die Zeile hat
/// eine Mindesthöhe, die über der Ziffernplakette liegt. Sonst wüchse die
/// Karte, sobald Satz-Uhrzeiten da sind.
class _NameZeile extends StatelessWidget {
  const _NameZeile({
    required this.sitzungId,
    required this.uebungId,
    required this.name,
    required this.abschnitt,
    required this.mitSchluessel,
  });

  final String sitzungId;
  final String uebungId;
  final String name;
  final GymPulsAbschnitt? abschnitt;
  final bool mitSchluessel;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final iron = CupertinoDynamicColor.resolve(Palette.iron, context);
    final a = abschnitt;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (a != null) ...[
            Container(
              key: mitSchluessel ? kGymVerlaufNr(sitzungId, uebungId) : null,
              width: 15,
              height: 15,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: iron.withValues(alpha: 0.26),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${a.abschnitt.position}',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: iron,
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          // **Eine Zeile, die nötigenfalls schrumpft, nie umbricht:** Mit
          // Ziffer und Ø bleibt dem Namen weniger Platz als ohne. Bräche er
          // dort um, wäre die Zeile höher, sobald Satz-Uhrzeiten da sind —
          // der Sprung, den „eine Form" verhindern soll.
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                name,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 14.4,
                  fontWeight: FontWeight.w600,
                  color: ink,
                ),
              ),
            ),
          ),
          if (a != null) ...[
            const SizedBox(width: 8),
            Semantics(
              label: gymPulsUebungVorlesetext(a.durchschnitt),
              excludeSemantics: true,
              child: Text(
                gymPulsUebungText(a.durchschnitt),
                key: mitSchluessel
                    ? kGymVerlaufUebungsPuls(sitzungId, uebungId)
                    : null,
                style: Typografie.tabularNumbers(
                  Typografie.numeric(
                    TypografieGroesse.footnote,
                    gewicht: FontWeight.w400,
                  ).copyWith(fontSize: 12.8, color: muted),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Die Plakette eines Satzes — „1  60 kg × 10" im Entwurf. Die Ziffer steht
/// **neben** dem Text des Satzes, nicht darin: Der Text ist das, was die
/// Ablage trägt.
class _Plakette extends StatelessWidget {
  const _Plakette({
    required this.schluessel,
    required this.nummer,
    required this.text,
  });

  final Key? schluessel;
  final int nummer;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final bg = CupertinoDynamicColor.resolve(Palette.bg, context);
    final line = CupertinoDynamicColor.resolve(Palette.line, context);
    final stil = Typografie.tabularNumbers(
      Typografie.numeric(
        TypografieGroesse.footnote,
        gewicht: FontWeight.w400,
      ).copyWith(fontSize: 13.4, color: ink),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: line, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$nummer', style: stil.copyWith(color: muted)),
            const SizedBox(width: 6),
            Text(text, key: schluessel, style: stil),
          ],
        ),
      ),
    );
  }
}
