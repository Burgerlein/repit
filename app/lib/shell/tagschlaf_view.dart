// Der Schirm `tagschlaf` (#92) — was am Tag geschlafen wurde, und
// **nichts von der Nacht**. Gepusht von der Tagschlaf-Zeile des
// Schlaf-Schirms. Der Zustand darunter (`tagschlafProvider`) liegt in
// `schlaf_zustand.dart`.
//
// API und Verhalten sind durch `app/test/shell/tagschlaf_view_test.dart`
// verbindlich vorgegeben (siehe dessen Dateikopf) — diese Datei darf die
// Tests ausführen, aber nicht verändern (`CLAUDE.md`, „Wer Tests schreibt,
// schreibt nicht die Implementierung").
//
// **Warum das ein eigener Schirm ist und kein Abschnitt:** `docs/SPEC.md`
// 4.6 führt den Tagschlaf getrennt — er geht nicht in Dauer, Score oder
// Wachzeit der Nacht ein. Ein Abschnitt auf dem Nacht-Schirm könnte diese
// Trennung gar nicht einhalten.
//
// **Eine Abweichung vom Entwurf `docs/screens/screens/tagschlaf.js`:**
//
// - **Die Datumszeile nennt nur den Tag**, nicht zusätzlich „Nacht von Mo
//   auf Di". Der Entwurf trägt beides, widerspricht damit aber seiner
//   eigenen Überschrift („hier steht bewusst nichts von der Nacht"). Das
//   ist eine Frage an Tim, keine stille Entscheidung — siehe Bericht.
//
// **Das (+) in der Navigationsleiste steht seit #131 da** (29.10.2026).
// Bis dahin fehlte es, weil ein Knopf, der nichts auslöst, derselbe Fehler
// wäre wie eine stumme Zeile, die aussieht wie eine Tür; jetzt löst er das
// Formular aus. Dieselbe Tür gibt es zusätzlich als Zeile am Seitenende —
// einen Weg im Kopf, einen im Fluss.
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/messwert.dart';
import '../data/schlaf_eintrag.dart';
import '../design/formatierung.dart';
import '../design/glas_abstand.dart';
import '../design/hinweisfuss.dart';
import '../design/hypnogramm.dart';
import '../design/inset_card.dart';
import '../design/palette.dart';
import '../design/section_header.dart';
import '../design/typografie.dart';
import '../health/health_types.dart';
import 'router.dart';
import 'schlaf_abschnitte.dart';
import 'schlaf_eintragen.dart';
import 'schlaf_view.dart' show SchlafEintragenZeile;
import 'schlaf_zustand.dart';
import 'ziele.dart';

/// Öffnet den Tagschlaf-Schirm auf dem Stapel des **aktuell gewählten**
/// Tabs.
void oeffneTagschlaf(AppRouter router) =>
    router.open(AppTarget.aktuell((context) => TagschlafSeite(router: router)));

/// Der Rahmen: Gerüst und Navigationsleiste.
///
/// Ein [AppRouter] steht hier, obwohl der Schirm heute keine eigene Tür
/// hat: Die Leiste gehört dem Gastgeber, und jeder andere gepushte Schirm
/// dieses Bereichs wird gleich gebaut.
class TagschlafSeite extends ConsumerWidget {
  const TagschlafSeite({super.key, required this.router});

  final AppRouter router;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Der Tag, den das Formular vorbelegt, kommt aus dem Zustand dieses
    // Schirms — nicht aus einer zweiten Uhr im Formular.
    final tag = ref.watch(tagschlafProvider).tag;

    return CupertinoPageScaffold(
      backgroundColor: CupertinoDynamicColor.resolve(Palette.bg, context),
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Tagschlaf'),
        // `Builder`, damit `showCupertinoModalPopup` einen Kontext
        // **unter** dem Navigator bekommt.
        trailing: Builder(
          builder: (context) => CupertinoButton(
            key: const Key('tagschlaf-plus'),
            padding: EdgeInsets.zero,
            minimumSize: const Size(44, 36),
            onPressed: () => zeigeSchlafEintragen(
              context,
              art: SchlafEintragenArt.tagschlaf,
              tag: tag,
            ),
            child: const Icon(CupertinoIcons.add_circled, size: 22),
          ),
        ),
      ),
      child: const TagschlafView(),
    );
  }
}

/// Der Schirm selbst — ohne Gerüst, ohne Leiste, ohne Navigator.
///
/// **Er nimmt keinen Tag entgegen.** Welcher Tag gemeint ist, entscheidet
/// [tagschlafProvider] aus der Auswahl des Nacht-Schirms; ein Parameter
/// daneben wäre eine zweite Wahrheit über denselben Tag, und der Schirm
/// besorgte seine Daten dann nicht mehr selbst.
class TagschlafView extends ConsumerWidget {
  const TagschlafView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zustand = ref.watch(tagschlafProvider);

    final List<Widget> inhalt = switch (zustand.phasen) {
      NochNie<List<SleepSession>>() => const [
        _Laden(key: Key('tagschlaf-laden')),
      ],
      // **Gar keine Schlafdaten.** Hier und nur hier werden beide
      // Möglichkeiten genannt — Apple verrät den Lesestatus nicht.
      LeerNachLauf<List<SleepSession>>() => const [
        _KeineDaten(key: Key('tagschlaf-keine-daten')),
      ],
      Fehlgeschlagen<List<SleepSession>>() => const [
        _Fehler(key: Key('tagschlaf-fehler')),
      ],
      // **Schlafdaten da, an diesem Tag aber kein Nickerchen.** Etwas
      // anderes: Die Lücke ist eindeutig, also wird nicht über eine
      // fehlende Freigabe spekuliert.
      // **Eingetragene Phasen zählen mit.** Gibt es nur sie, ist der Tag
      // trotzdem nicht leer — die Uhr erkennt Tagschlaf fast nie, genau
      // deshalb gibt es das Formular.
      Bekannt<List<SleepSession>>(:final wert) =>
        zustand.hatPhasen
            ? _phasen(zustand, wert)
            : const [_OhneNickerchen(key: Key('tagschlaf-leer'))],
    };

    return SingleChildScrollView(
      padding: GlasAbstand.of(context) + const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Datum(key: const Key('tagschlaf-datum'), tag: zustand.tag),
          ...inhalt,

          const SectionHeader('Fehlt ein Nickerchen?'),
          SchlafEintragenZeile(
            schluessel: const Key('tagschlaf-eintragen'),
            titel: 'Tagschlaf von Hand eintragen',
            untertitel: 'die Uhr erkennt ihn fast nie',
            art: SchlafEintragenArt.tagschlaf,
            tag: zustand.tag,
          ),
          const Hinweisfuss(
            // **„Bewertung", nicht „Score".** Auf diesem Schirm steht
            // nichts von der Nacht, und der Entwurf schreibt an dieser
            // Stelle „Score" — `tagschlaf_view_test.dart` schließt das
            // Wort hier aus, und zu Recht: Die Fußnote daneben sagt seit
            // #92 aus demselben Grund „ihre Bewertung".
            'Von Hand eingetragener Tagschlaf liegt in dieser App, nicht '
            'in Apple Health. Er zählt — wie der gemessene — nicht in '
            'Dauer, Bewertung oder Wachzeit der Nacht.',
            key: Key('tagschlaf-eintragen-hinweis'),
          ),

          const Hinweisfuss(
            'Eine eigene Schlafphase, von der Nacht durch eine Pause von '
            'über vier Stunden getrennt. Sie zählt nicht in die '
            'Schlafdauer der Nacht und nicht in ihre Bewertung — ein '
            'Nickerchen soll keine kurze Nacht aufpolieren. Eine '
            'Schätzung aus Apple-Health-Werten, keine medizinische '
            'Bewertung.',
            key: Key('tagschlaf-fussnote'),
          ),
        ],
      ),
    );
  }

  List<Widget> _phasen(TagschlafZustand zustand, List<SleepSession> phasen) => [
    _Summe(
      key: const Key('tagschlaf-summe'),
      minuten: zustand.minuten,
      anzahl: zustand.anzahl,
    ),
    for (var i = 0; i < phasen.length; i++)
      _PhasenKarte(key: Key('tagschlaf-phase-$i'), phase: phasen[i]),
    // Die eingetragenen stehen hinter den gemessenen — sie kommen dazu,
    // sie ersetzen keine.
    for (var i = 0; i < zustand.eintraege.length; i++)
      _EingetrageneKarte(
        key: Key('tagschlaf-eintrag-$i'),
        eintrag: zustand.eintraege[i],
      ),
  ];
}

/// Eine eingetragene Phase — **ohne Hypnogramm**. Wer die Phasen nicht
/// gemessen hat, hat keine; die Zeile sagt das, statt eine leere Grafik zu
/// zeigen.
class _EingetrageneKarte extends StatelessWidget {
  const _EingetrageneKarte({super.key, required this.eintrag});

  final SchlafEintrag eintrag;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: InsetCard(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DAUER',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.6,
                            color: muted,
                          ),
                        ),
                        Text(
                          tagschlafDauerText(eintrag.schlafMinuten.toDouble()),
                          style: Typografie.tabularNumbers(
                            Typografie.numeric(
                              TypografieGroesse.title,
                              gewicht: FontWeight.w700,
                            ),
                          ).copyWith(color: ink),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'von Hand',
                          style: TextStyle(fontSize: 11, color: muted),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    schlafFensterTextAusMinuten(
                      eintrag.beginnMinuten,
                      eintrag.endeMinuten,
                    ),
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Text(
                'Keine Schlafphasen — von Hand eingetragen, nicht '
                'gemessen.',
                style: TextStyle(fontSize: 12, height: 1.35, color: muted),
              ),
              if (eintrag.notiz != null) ...[
                const SizedBox(height: 4),
                Text(
                  eintrag.notiz!,
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Datum extends StatelessWidget {
  const _Datum({super.key, required this.tag});

  final DateTime tag;

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
      child: Text(
        // Über `Format` mit fest gesetzter Sprache: Auf einem englisch
        // eingestellten Gerät stünde hier sonst „October" mitten im
        // deutschen Text (`CLAUDE.md`).
        Format.wochentagUndDatum(kalendertag(tag)),
        style: TextStyle(fontSize: 13, color: muted),
      ),
    );
  }
}

/// „AM TAG GESCHLAFEN" — die Zahl, die man sucht.
class _Summe extends StatelessWidget {
  const _Summe({super.key, required this.minuten, required this.anzahl});

  final double minuten;
  final int anzahl;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: InsetCard(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AM TAG GESCHLAFEN',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                  color: muted,
                ),
              ),
              Text(
                tagschlafDauerText(minuten),
                style: Typografie.tabularNumbers(
                  Typografie.numeric(
                    TypografieGroesse.largeTitle,
                    gewicht: FontWeight.w700,
                  ),
                ).copyWith(color: ink),
              ),
              Text(
                anzahl == 1 ? '1 Phase' : '$anzahl Phasen',
                style: TextStyle(fontSize: 12, color: muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Je Phase eine Karte mit **eigenem** Hypnogramm — nicht eines über alle,
/// das die Stunden dazwischen als Schlaf zeichnete.
class _PhasenKarte extends StatelessWidget {
  const _PhasenKarte({super.key, required this.phase});

  final SleepSession phase;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);

    final geometrie = HypnogrammGeometrie(phase);
    var wach = 0.0;
    for (final abschnitt in phase.segments) {
      if (abschnitt.stage != SleepStage.awake) continue;
      wach +=
          abschnitt.end.difference(abschnitt.start).inMicroseconds /
          Duration.microsecondsPerMinute;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: InsetCard(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DAUER',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.6,
                            color: muted,
                          ),
                        ),
                        Text(
                          tagschlafDauerText(schlafMinutenVon(phase)),
                          style: Typografie.tabularNumbers(
                            Typografie.numeric(
                              TypografieGroesse.title2,
                              gewicht: FontWeight.w700,
                            ),
                          ).copyWith(color: ink),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        schlafFensterText(geometrie.von, geometrie.bis),
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                      if (wach > 0)
                        Text(
                          '${wach.round()} min wach',
                          style: TextStyle(fontSize: 12, color: muted),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Hypnogramm(session: phase, kompakt: false),
            ],
          ),
        ),
      ),
    );
  }
}

/// „32 min" unter einer Stunde, sonst „1:15 h". Eine Null steht hier nie —
/// den Fall fängt der leere Zweig ab, bevor es dazu kommt.
String tagschlafDauerText(double minuten) {
  final gesamt = minuten.round();
  if (gesamt < Duration.minutesPerHour) return '$gesamt min';
  return schlafDauerText(minuten);
}

// ───────────────────────────────────────────────────────────────────────
// Die Zweige ohne Phasen
// ───────────────────────────────────────────────────────────────────────

class _Laden extends StatelessWidget {
  const _Laden({super.key});

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 36, 20, 36),
      // **Kein Grund während des Laufs** (`docs/todo/01`) — und kein
      // Ladekreisel: Der dreht sich endlos, und `pumpAndSettle` käme in
      // keinem Widget-Test je zur Ruhe. Ein Satz sagt dasselbe.
      child: Text(
        'Schlafdaten werden gelesen …',
        style: TextStyle(fontSize: 13, color: muted),
      ),
    );
  }
}

class _KeineDaten extends StatelessWidget {
  const _KeineDaten({super.key});

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 36, 20, 36),
      child: Text(
        'Es liegen gar keine Schlafdaten vor. Zwei Erklärungen, beide '
        'möglich: Entweder hat die Uhr nichts aufgezeichnet — oder der '
        'Lesezugriff auf Schlaf ist nicht freigegeben. Apple verrät '
        'nicht, welches von beidem zutrifft.',
        style: TextStyle(fontSize: 13, height: 1.4, color: muted),
      ),
    );
  }
}

class _Fehler extends StatelessWidget {
  const _Fehler({super.key});

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 36, 20, 36),
      child: Text(
        'Die Schlafdaten konnten nicht gelesen werden. Das sagt nichts '
        'darüber, ob welche vorliegen — es hat nur gerade nicht geklappt. '
        'Später noch einmal versuchen.',
        style: TextStyle(fontSize: 13, height: 1.4, color: muted),
      ),
    );
  }
}

/// Schlafdaten sind da, an diesem Tag aber kein Nickerchen.
///
/// **Hier wird nicht über eine fehlende Freigabe spekuliert** — die Lücke
/// ist eindeutig. Behauptet wird trotzdem nicht, am Tag sei nicht
/// geschlafen worden: Die Uhr erkennt Tagschlaf schlecht, und das sagt der
/// Schirm (`docs/SPEC.md` 4.6: in 124 Nächten genau ein erkannter
/// Tagschlaf).
class _OhneNickerchen extends StatelessWidget {
  const _OhneNickerchen({super.key});

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 36, 20, 36),
      child: Text(
        'An diesem Tag ist kein Nickerchen aufgezeichnet. Die Uhr erkennt '
        'Tagschlaf schlecht — ein Mittagsschlaf im Sessel ist fast nie '
        'dabei.',
        style: TextStyle(fontSize: 13, height: 1.4, color: muted),
      ),
    );
  }
}
