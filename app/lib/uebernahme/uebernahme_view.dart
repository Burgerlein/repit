// Der Schirm „Daten übernehmen" (#59 Teil 1, mit #482; Umfänge #498):
// Gym-Trainings **und Umfänge** aus der Exportdatei der eingefrorenen
// Swift-App in den Neubau holen — nur dazuschreiben, nie ersetzen, nie
// löschen.
//
// API und Schlüssel sind durch `app/test/uebernahme/uebernahme_support.dart`
// und `uebernahme_view_test.dart` verbindlich vorgegeben (siehe deren
// Dateiköpfe) — diese Datei darf die Tests ausführen, aber nicht verändern
// (`CLAUDE.md`). Spec: `docs/superpowers/specs/2026-11-11-gym-uebernahme-
// design.md`, Abschnitt 7.
//
// **Eine Anzeige, die es gibt, hat genau eine Form** (`CLAUDE.md`): Meldung,
// Ergebniskarte mit ihren fünf Wertplätzen, Knopf und Hinweis stehen in jedem
// Zustand da, an derselben Stelle. Nur die Füllung ändert sich — `–/–` vor
// dem ersten Lauf, während des Laufs und nach einer abgelehnten oder
// gescheiterten Übernahme. **`0` ist keine Antwort auf „kein Wert"** (Fehler
// `01`); nach einem gelaufenen Lauf ist sie eine.
//
// **Das Ergebnis liegt im Provider** (`uebernahme_provider.dart`), nicht im
// Widget: Es steht nach dem Zurücknavigieren wieder da (Fehler `32`).
//
// Aufbau nach Spec 7.2 und dem Entwurf `docs/screens/screens/import.js`:
// Meldung, **zwei** Ergebniskarten (Trainings, Umfänge), die Zeilen zu
// Übersprungenem und Nicht-Lesbarem, der Knopf, der Hinweis am Fuß.
//
// **Zwei Karten und nicht eine:** Die fünf Wertplätze der Trainings-Karte
// zählen Sitzungen, die Umfänge zählen Einzelwerte. In derselben Karte
// stünde „Neu übernommen" zweimal und meinte zweimal etwas anderes.
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../design/glas_abstand.dart';
import '../design/grosse_ueberschrift.dart';
import '../design/hinweisfuss.dart';
import '../design/inset_card.dart';
import '../design/palette.dart';
import '../design/platzhalter.dart';
import '../design/section_header.dart';
import '../design/typografie.dart';
import '../shell/router.dart';
import '../shell/ziele.dart';
import 'trainingsexport_uebernahme.dart';
import 'uebernahme_provider.dart';
import 'uebernahme_schluessel.dart';
import 'uebernahme_texte.dart';

/// Öffnet „Daten übernehmen" auf dem Stapel des **aktuell gewählten** Tabs —
/// die eine Stelle, die das weiß. `AppTarget.aktuell`, nicht `.detail`: Der
/// Schirm hängt im Menü unter Mehr, wechselt aber nie dorthin — sonst führte
/// „zurück" in ein Menü, das der Nutzer nie geöffnet hat (`CLAUDE.md`).
void oeffneUebernahme(AppRouter router) =>
    router.open(AppTarget.aktuell((context) => const UebernahmeSeite()));

/// Der Rahmen: Gerüst und Navigationsleiste um [UebernahmeView].
///
/// **Kein eigener `Navigator`** — den stellt `RootView`. Zwei verschachtelte
/// Stapel schließen die gepushte Seite sofort wieder (`CLAUDE.md`).
class UebernahmeSeite extends StatelessWidget {
  const UebernahmeSeite({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoDynamicColor.resolve(Palette.bg, context),
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Daten übernehmen'),
      ),
      child: const UebernahmeView(),
    );
  }
}

class UebernahmeView extends ConsumerWidget {
  const UebernahmeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stand = ref.watch(uebernahmeProvider);
    // Nur ein gelaufener Lauf trägt Zahlen. Vor dem ersten, während des
    // Laufs und nach Ablehnung oder Scheitern bleibt die Karte ungefüllt.
    final ergebnis = stand is UebernahmeFertig ? stand.ergebnis : null;

    return SingleChildScrollView(
      padding: GlasAbstand.of(context) + const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const GrosseUeberschrift(
            'Daten übernehmen',
            einordnung: 'Gym-Trainings und Umfänge aus der alten App',
          ),
          _Meldung(stand: stand),
          const SectionHeader('Trainings'),
          _Ergebnis(ergebnis: ergebnis),
          const SectionHeader('Umfänge'),
          _Umfaenge(ergebnis: ergebnis),
          if (ergebnis != null) ..._nachLauf(context, ergebnis),
          _Knopf(
            laeuft: stand is UebernahmeLaeuft,
            aufTipp: () =>
                ref.read(uebernahmeProvider.notifier).waehleUndUebernimm(),
          ),
          const Hinweisfuss(uebernahmeUmfangText, key: kUebernahmeUmfang),
        ],
      ),
    );
  }

  /// Was nach einem Lauf darunter steht: die Zeilen zu Übersprungenem und
  /// Nicht-Lesbarem und die Hinweise auf Unbekanntes, Ungelesenes und eine
  /// andere Zeitzone.
  List<Widget> _nachLauf(BuildContext context, TrainingsexportUebernommen e) {
    final ausgelassen = [
      for (final s in e.uebersprungen)
        if (s.reason != GymImportSkipReason.alreadyPresent) s,
    ];
    return [
      _Beiwerk(berichtZeile(e)),
      if (ausgelassen.isNotEmpty) ...[
        const SectionHeader('Nicht übernommen'),
        InsetCard(
          child: _Zeilen([
            for (final s in ausgelassen)
              _Zeile(
                key: kUebernahmeAuslassung(s.session.id),
                text: auslassungText(s),
              ),
          ]),
        ),
      ],
      if (e.nichtLesbar.isNotEmpty) ...[
        const SectionHeader('Nicht lesbar'),
        InsetCard(
          child: _Zeilen([
            for (final s in e.nichtLesbar)
              _Zeile(
                key: kUebernahmeNichtLesbar(s.index),
                text: nichtLesbarText(s),
              ),
          ]),
        ),
      ],
      if (e.umfaengeNichtLesbar.isNotEmpty) ...[
        const SectionHeader('Umfänge — nicht lesbar'),
        InsetCard(
          child: _Zeilen([
            for (final s in e.umfaengeNichtLesbar)
              _Zeile(
                key: kUebernahmeUmfaengeNichtLesbar(s.index),
                text: umfangNichtLesbarText(s),
              ),
          ]),
        ),
      ],
      if (e.unbekannteUebungen.isNotEmpty || e.unbekannteWorkouts.isNotEmpty)
        _Hinweis(key: kUebernahmeUnbekannt, text: unbekanntText(e)),
      if (e.unbekannteMasse.isNotEmpty)
        _Hinweis(
          key: kUebernahmeUmfaengeUnbekannt,
          text: unbekannteMasseText(e.unbekannteMasse),
        ),
      if (e.ungelesen.isNotEmpty)
        _Hinweis(key: kUebernahmeUngelesen, text: ungelesenText(e.ungelesen)),
      if (e.zeitzone != 'Europe/Berlin')
        _Hinweis(key: kUebernahmeZeitzone, text: zeitzoneText(e.zeitzone)),
    ];
  }
}

/// Genau eine der fünf Meldungen — jede mit eigenem Schlüssel, damit ein
/// Test (und jeder Leser) sagen kann, welche gerade steht.
class _Meldung extends StatelessWidget {
  const _Meldung({required this.stand});

  final UebernahmeStand stand;

  Key get _schluessel => switch (stand) {
    UebernahmeLeer() => kUebernahmeLeer,
    UebernahmeLaeuft() => kUebernahmeLaeuft,
    UebernahmeFertig() => kUebernahmeFertig,
    UebernahmeAbgelehnt() => kUebernahmeAbgelehnt,
    UebernahmeGescheitert() => kUebernahmeGescheitert,
  };

  Color _farbe(BuildContext context) =>
      CupertinoDynamicColor.resolve(switch (stand) {
        UebernahmeAbgelehnt() || UebernahmeGescheitert() => Palette.warn,
        UebernahmeFertig() => Palette.ok,
        _ => Palette.muted,
      }, context);

  @override
  Widget build(BuildContext context) {
    const stil = TextStyle(fontSize: 15, height: 1.35);
    // Eine Mindesthöhe statt einer festen: Die Meldungen schwanken zwischen
    // einer und sechs Zeilen, und der Schirm darunter soll nicht springen,
    // wenn sie wechseln.
    final mindesthoehe = textMass(
      context,
      List<String>.filled(6, 'X').join('\n'),
      stil,
    ).height;
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      child: InsetCard(
        child: Container(
          key: _schluessel,
          constraints: BoxConstraints(minHeight: mindesthoehe + 28),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: _farbe(context), width: 4)),
          ),
          alignment: Alignment.topLeft,
          child: Text(
            uebernahmeMeldung(stand),
            style: stil.copyWith(color: ink),
          ),
        ),
      ),
    );
  }
}

/// Die Karte mit den fünf Wertplätzen — in jedem Zustand da.
class _Ergebnis extends StatelessWidget {
  const _Ergebnis({required this.ergebnis});

  /// `null` heißt: kein Lauf, der eine Zahl hergibt.
  final TrainingsexportUebernommen? ergebnis;

  @override
  Widget build(BuildContext context) {
    final e = ergebnis;
    final line = CupertinoDynamicColor.resolve(Palette.line, context);

    Widget zeile(String beschriftung, Key schluessel, int? zahl) => _ZahlZeile(
      beschriftung: beschriftung,
      schluessel: schluessel,
      zahl: zahl,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      child: InsetCard(
        child: Column(
          key: kUebernahmeErgebnis,
          children: [
            zeile('In der Datei', kZahlInDatei, e?.inDatei),
            _Trenner(line),
            zeile('Neu übernommen', kZahlNeu, e?.neu),
            _Trenner(line),
            zeile('Schon da', kZahlSchonDa, e?.schonDa),
            _Trenner(line),
            zeile(
              'Nicht übernommen',
              kZahlNichtUebernommen,
              e?.nichtUebernommen,
            ),
            _Trenner(line),
            zeile('Nicht lesbar', kZahlNichtLesbar, e?.nichtLesbar.length),
          ],
        ),
      ),
    );
  }
}

/// Die Karte der Umfänge — **in jedem Zustand da** (#498).
///
/// Sie fällt nicht weg, wenn eine Datei keine Messungen trägt: Dann stünde
/// dort nichts, und eine Datei ohne Umfänge sähe aus wie eine App, die sie
/// nicht liest. Nach einem gelaufenen Lauf ist die `0` eine Antwort.
class _Umfaenge extends StatelessWidget {
  const _Umfaenge({required this.ergebnis});

  /// `null` heißt: kein Lauf, der eine Zahl hergibt.
  final TrainingsexportUebernommen? ergebnis;

  @override
  Widget build(BuildContext context) {
    final e = ergebnis;
    final line = CupertinoDynamicColor.resolve(Palette.line, context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      child: InsetCard(
        child: Column(
          key: kUebernahmeErgebnisUmfaenge,
          children: [
            _ZahlZeile(
              beschriftung: 'Neu übernommen',
              schluessel: kZahlUmfaengeNeu,
              zahl: e?.umfaengeNeu,
              zusatzSchluessel: kTageUmfaengeNeu,
              zusatz: e == null ? null : umfaengeTageText(e.umfaengeTage),
            ),
            _Trenner(line),
            _ZahlZeile(
              beschriftung: 'Schon da',
              schluessel: kZahlUmfaengeSchonDa,
              zahl: e?.umfaengeSchonDa,
              zusatzSchluessel: kTageUmfaengeSchonDa,
              zusatz: e == null
                  ? null
                  : umfaengeTageText(e.umfaengeSchonVorhanden.length),
            ),
            _Trenner(line),
            _ZahlZeile(
              beschriftung: 'Nicht lesbar',
              schluessel: kZahlUmfaengeNichtLesbar,
              zahl: e?.umfaengeNichtLesbar.length,
            ),
          ],
        ),
      ),
    );
  }
}

class _Trenner extends StatelessWidget {
  const _Trenner(this.farbe);

  final Color farbe;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 14),
    child: Container(height: 1, color: farbe),
  );
}

/// Eine Zeile der Karte: links die Beschriftung, rechts die Zahl — oder
/// `–/–`. **Der Wertplatz trägt nur die Zahl**, ohne Beschriftung.
///
/// [zusatz] ist der graue Nachsatz der Umfänge-Karte („an 2 Tagen"). Er
/// steht in einem **eigenen** Knoten mit eigenem Schlüssel, damit die Zahl
/// eine Zahl bleibt: „26 Werte an 2 Tagen" in einem Textknoten ließe
/// weder das eine noch das andere prüfen.
class _ZahlZeile extends StatelessWidget {
  const _ZahlZeile({
    required this.beschriftung,
    required this.schluessel,
    required this.zahl,
    this.zusatz,
    this.zusatzSchluessel,
  });

  final String beschriftung;
  final Key schluessel;
  final int? zahl;

  /// `null` heißt entweder „diese Zeile hat keinen Zusatz" (dann ist auch
  /// [zusatzSchluessel] `null`) oder „kein Lauf, der eine Zahl hergibt" —
  /// dann steht dort `–/–` wie bei der Zahl selbst. **Der Platz
  /// verschwindet nicht**, sonst sprängen Zeilenbreite und -inhalt zwischen
  /// den Zuständen (`CLAUDE.md`, „Eine Anzeige, die es gibt, hat genau eine
  /// Form").
  final String? zusatz;
  final Key? zusatzSchluessel;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final zahlStil = Typografie.tabularNumbers(
      Typografie.numeric(TypografieGroesse.title3),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              beschriftung,
              style: TextStyle(fontSize: 15, color: ink),
            ),
          ),
          Text(
            zahl == null ? ohneWert : '$zahl',
            key: schluessel,
            // Der Vorlesetext nennt den Zustand, nicht das Zeichen.
            semanticsLabel: zahl == null ? '$beschriftung, keine Werte' : null,
            style: zahlStil.copyWith(color: zahl == null ? muted : ink),
          ),
          if (zusatzSchluessel != null) ...[
            const SizedBox(width: 8),
            Text(
              zusatz ?? ohneWert,
              key: zusatzSchluessel,
              semanticsLabel: zusatz == null ? 'keine Werte' : null,
              style: TextStyle(fontSize: 13, color: muted),
            ),
          ],
        ],
      ),
    );
  }
}

/// Die Zeilen zu Übersprungenem und Nicht-Lesbarem, durch Linien getrennt.
class _Zeilen extends StatelessWidget {
  const _Zeilen(this.zeilen);

  final List<_Zeile> zeilen;

  @override
  Widget build(BuildContext context) {
    final line = CupertinoDynamicColor.resolve(Palette.line, context);
    return Column(
      children: [
        for (var i = 0; i < zeilen.length; i++) ...[
          zeilen[i],
          if (i < zeilen.length - 1) _Trenner(line),
        ],
      ],
    );
  }
}

class _Zeile extends StatelessWidget {
  const _Zeile({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: TextStyle(fontSize: 14, height: 1.3, color: ink),
        ),
      ),
    );
  }
}

/// Ein Hinweis unter der Karte — nur, wenn es etwas zu sagen gibt.
class _Hinweis extends StatelessWidget {
  const _Hinweis({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Text(
        text,
        style: TextStyle(fontSize: 13, height: 1.4, color: muted),
      ),
    );
  }
}

/// Beiwerk zur Karte: Sätze, Zeitraum, Erzeugung der Datei.
class _Beiwerk extends StatelessWidget {
  const _Beiwerk(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Text(text, style: TextStyle(fontSize: 12, color: muted)),
    );
  }
}

/// „Exportdatei wählen" — **in jedem Zustand da.** Während des Laufs ist er
/// ausgegraut und löst nicht ein zweites Mal aus; er verschwindet nicht.
class _Knopf extends StatelessWidget {
  const _Knopf({required this.laeuft, required this.aufTipp});

  final bool laeuft;
  final VoidCallback aufTipp;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 0),
      child: CupertinoButton.filled(
        key: kUebernahmeWaehlen,
        onPressed: laeuft ? null : aufTipp,
        child: const Text('Exportdatei wählen'),
      ),
    );
  }
}
