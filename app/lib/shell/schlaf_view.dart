// Der Schirm `schlaf` (#92) — alles zur Nacht, gepusht vom Schlaf-Ring der
// Erholungsseite. Der Zustand darunter liegt in `schlaf_zustand.dart`, die
// einzelnen Abschnitte in `schlaf_abschnitte.dart`, der Tagschlaf auf einem
// eigenen Schirm (`tagschlaf_view.dart`).
//
// API und Verhalten sind durch `app/test/shell/schlaf_view_test.dart`
// verbindlich vorgegeben (siehe dessen Dateikopf) — diese Datei darf die
// Tests ausführen, aber nicht verändern (`CLAUDE.md`, „Wer Tests schreibt,
// schreibt nicht die Implementierung").
//
// Aufbau nach `docs/screens/screens/schlaf.js` und `docs/SPEC.md` 4.6.
// **Eine Abweichung vom Entwurf, entschieden:**
//
// - **Keine Stufe `T` im Verlauf.** `W M 6M J`, wie `docs/SPEC.md` 4.6 es
//   verlangt — eine Nacht hat keine Stundenwerte.
//
// **„Nacht von Hand eintragen" steht seit #131 da** (29.10.2026). Bis
// dahin fehlte die Zeile, weil ein Knopf ohne Funktion schlimmer ist als
// keiner; jetzt gibt es die Funktion. Sie liegt unauffällig am Seitenende
// — die gemessene Nacht ist der Normalfall, der Eintrag die Ausnahme —,
// **im leeren Zustand dagegen ganz oben**, weil sie dort als einzige
// weiterführt (`schlaf.js`, Zustand `leer`).
//
// **Die Tür hängt seit dem 28.10.2026:** Zwei Stellen des Erholung-Schirms
// führen hierher — der Ring „SCHLAF" und der Kopf der Nachtkarte („die
// ganze Nacht" ist kein eigener Schirm, sondern das, was dieser zeigt).
// Beide gehen über [oeffneSchlaf].
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trainings_core/trainings_core.dart' show BerlinCalendar;

import '../core/messwert.dart';
import '../data/schlaf_eintrag.dart';
import '../design/formatierung.dart';
import '../design/glas_abstand.dart';
import '../design/hinweisfuss.dart';
import '../design/hypnogramm.dart';
import '../design/inset_card.dart';
import '../design/klapp_abschnitt.dart';
import '../design/palette.dart';
import '../design/section_header.dart';
import '../health/health_types.dart';
import 'router.dart';
import 'schlaf_abschnitte.dart';
import 'schlaf_eintragen.dart';
import 'schlaf_kalenderblatt.dart';
import 'schlaf_zustand.dart';
import 'tagschlaf_view.dart';
import 'ziele.dart';

/// Öffnet den Schlaf-Schirm auf dem Stapel des **aktuell gewählten** Tabs —
/// die eine Stelle, die das weiß.
///
/// `AppTarget.aktuell`, nicht `.detail`: Ein Schirm, der im Menü unter
/// einem bestimmten Tab einsortiert ist, wechselt trotzdem nie dorthin,
/// sonst führte „zurück" in ein Menü, das der Nutzer nie geöffnet hat
/// (`CLAUDE.md`).
void oeffneSchlaf(AppRouter router) =>
    router.open(AppTarget.aktuell((context) => SchlafSeite(router: router)));

/// Der Rahmen: Gerüst, Navigationsleiste und das Kalenderblatt oben rechts.
///
/// Den stellt der Gastgeber, nicht der Schirm. **Kein eigener `Navigator`:**
/// Diese Ansicht wird auf den Stapel eines Tabs geschoben, der Stapel
/// gehört weiter `RootView`.
class SchlafSeite extends StatelessWidget {
  const SchlafSeite({super.key, required this.router});

  final AppRouter router;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoDynamicColor.resolve(Palette.bg, context),
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Schlaf'),
        // `Builder`, damit `showCupertinoModalPopup` einen Kontext
        // **unter** dem Navigator bekommt.
        trailing: Builder(
          builder: (context) => CupertinoButton(
            key: const Key('schlaf-kalender-knopf'),
            padding: EdgeInsets.zero,
            minimumSize: const Size(44, 36),
            onPressed: () => showCupertinoModalPopup<void>(
              context: context,
              builder: (_) =>
                  const SchlafKalenderblatt(key: Key('schlaf-kalenderblatt')),
            ),
            child: const Icon(CupertinoIcons.calendar, size: 22),
          ),
        ),
      ),
      child: SchlafView(router: router),
    );
  }
}

/// Der Schirm selbst — ohne Gerüst, ohne Leiste, ohne Navigator.
///
/// **Er besorgt seine Daten selbst** ([schlafProvider]): Jeder Schirm ist
/// aus jedem Tab erreichbar, niemand darf sich darauf verlassen, dass eine
/// Übersicht vorher geladen hat.
class SchlafView extends ConsumerWidget {
  const SchlafView({super.key, required this.router});

  final AppRouter router;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zustand = ref.watch(schlafProvider);
    final auswahl = ref.read(schlafAuswahlProvider.notifier);

    // Der `switch` über den sealed-Typ ist vollständig: Käme ein fünfter
    // Zustand, zeigte der Analyzer genau hier hin.
    final List<Widget> inhalt = switch (zustand.daten) {
      NochNie<SchlafDaten>() => const [_Laden(key: Key('schlaf-laden'))],
      // **Ein gewählter Tag schlägt den Leerzustand** (#177): „Für diesen
      // Zeitraum liegen keine Nächte vor" ist eine Aussage über den ganzen
      // Schirm; wer einen Tag angetippt hat, will etwas über **diesen** Tag
      // wissen. Die Zeile zu den Freigaben bleibt trotzdem stehen — solange
      // der Lauf gar nichts brachte, ist die Freigabefrage offen, und sie zu
      // verschlucken, weil gerade ein Tag gewählt ist, wäre die falsche
      // Reihenfolge.
      LeerNachLauf<SchlafDaten>() =>
        ref.watch(schlafAuswahlProvider) == null
            ? [
                const _Leer(key: Key('schlaf-leer')),
                ..._eintragen(context, zustand.heute),
              ]
            : _leererTag(
                context,
                ref,
                zustand,
                ref.watch(schlafAuswahlProvider)!,
                auswahl,
                mitFreigaben: true,
              ),
      Fehlgeschlagen<SchlafDaten>() => const [
        _Fehler(key: Key('schlaf-fehler')),
      ],
      Bekannt<SchlafDaten>(:final wert) => switch ((
        wert.nacht,
        wert.gezeigterTag,
      )) {
        (final SchlafNacht nacht, _) => _nacht(
          context,
          ref,
          zustand,
          wert,
          nacht,
          auswahl,
        ),
        // Es gibt Nächte, nur an diesem Tag keine — nicht dasselbe wie
        // „überhaupt keine".
        (null, final DateTime tag) => _leererTag(
          context,
          ref,
          zustand,
          tag,
          auswahl,
          daten: wert,
        ),
        (null, null) => [
          const _Leer(key: Key('schlaf-leer')),
          ..._eintragen(context, zustand.heute),
        ],
      },
    };

    // `padding` statt einer äußeren `Padding`: Eine äußere `Padding`
    // verkleinerte den Scroll-Viewport, statt den Inhalt darin einzurücken
    // — dann liefe er nicht mehr sichtbar unter der Leiste durch
    // (`GlasAbstand`-Klassenkommentar).
    return SingleChildScrollView(
      padding: GlasAbstand.of(context) + const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: inhalt,
      ),
    );
  }

  List<Widget> _nacht(
    BuildContext context,
    WidgetRef ref,
    SchlafZustand zustand,
    SchlafDaten daten,
    SchlafNacht nacht,
    SchlafAuswahlNotifier auswahl,
  ) {
    final statistik7 = daten.statistik7;
    final statistik30 = daten.statistik30;

    // Pfeil und Wischgeste rufen **dasselbe**; `null` heißt an beiden
    // Stellen „am Rand".
    final aufFrueher = daten.frueher == null
        ? null
        : () => auswahl.blaettere(SchlafBlaettern.frueher);
    final aufSpaeter = daten.spaeter == null
        ? null
        : () => auswahl.blaettere(SchlafBlaettern.spaeter);

    // **Nur der Nachtbereich wischt** (#127): die Blätterleiste mit der
    // Score-Karte und die drei Karten, die dieselbe Nacht zeigen.
    // Verlauf, Statistiken und die sieben Nächte beziehen sich auf heute
    // (Entscheidung 3 vom 13.10.2026) — sie blättern deshalb nicht mit,
    // und der Verlauf hat seine eigene waagerechte Geste.
    Widget wischbar(Widget kind) => SchlafWischen(
      aufFrueher: aufFrueher,
      aufSpaeter: aufSpaeter,
      child: kind,
    );

    return [
      wischbar(
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SchlafBlaetterleiste(
              key: const Key('schlaf-blaetterleiste'),
              datum: nacht.nacht.date,
              // **`fensterText`, nicht `schlafFensterText(von, bis)`.** Der
              // Doc-Kommentar an `SchlafNacht.fensterText` nennt sich „die
              // **eine** Stelle, an der diese Wahl getroffen wird — zwei
              // Stellen des Schirms zeigen dasselbe Fenster"; diese hier
              // ging bisher daran vorbei. Bei einer von Hand eingetragenen
              // Nacht hat `von`/`bis` keine Abschnitte, also stand in der
              // Leiste „—", während die Karte vierzig Punkte tiefer die
              // eingetippten Uhrzeiten zeigte. Ein Kommentar, der zusichert,
              // was der Code nicht durchsetzt, ist schlimmer als gar keiner.
              fenster: nacht.fensterText,
              aufFrueher: aufFrueher,
              aufSpaeter: aufSpaeter,
            ),

            SchlafScoreKarte(
              key: const Key('schlaf-scorekarte'),
              nacht: nacht,
              ziele: zustand.ziele,
            ),

            // **Der Kasten steht unter der Karte, nicht darüber** (#429).
            // Darüber schob er sie beim Blättern auf eine eingetragene
            // Nacht um seine eigene Höhe nach unten — so steht die Karte
            // bei jeder Nacht an derselben Stelle. Auf dem Board stand er
            // schon immer hier.
            if (nacht.vonHand != null)
              _EintragHinweis(
                key: const Key('schlaf-von-hand-hinweis'),
                tag: nacht.nacht.date,
                text:
                    'Diese Nacht hast du selbst eingetragen. Schlafphasen, '
                    'Puls und Atemfrequenz gibt es dafür nicht — die '
                    'Abschnitte entfallen. Dauer und Einschlafzeit zählen '
                    'ganz normal in die Bewertung.',
              )
            // **Ein Eintrag, der die Messung nicht überlappt, ersetzt sie
            // nicht** (#192) — dann steht die gemessene Nacht vollständig
            // da, und der Kasten sagt, was dazugekommen ist und was es
            // nicht mitbringt.
            else if (nacht.ergaenzung case final ergaenzung?)
              _EintragHinweis(
                key: const Key('schlaf-ergaenzung-hinweis'),
                tag: nacht.nacht.date,
                text:
                    'Dazu hast du '
                    '${schlafDauerText(ergaenzung.schlafMinuten.toDouble())} '
                    'selbst eingetragen '
                    '(${schlafFensterTextAusMinuten(ergaenzung.beginnMinuten, ergaenzung.endeMinuten)}). '
                    'Die Zeit zählt in Dauer und Bewertung mit. Schlafphasen, '
                    'Puls und Atemfrequenz gibt es dafür nicht, und '
                    '„Unterbrechungen" zählt nur die gemessene Strecke.',
              ),

            // **Eine Tür, kein Abschnitt.** Ohne Nickerchen gibt es die
            // Zeile nicht — eine Zeile „0 min" behauptete eine Messung.
            if (nacht.tagschlafAnzahl > 0)
              _TagschlafZeile(
                key: const Key('schlaf-tagschlaf'),
                minuten: nacht.tagschlafMinuten,
                anzahl: nacht.tagschlafAnzahl,
                router: router,
              ),
          ],
        ),
      ),

      // **Eine von Hand eingetragene Nacht hat davon nichts.** Gemessen
      // wurde nichts, also wird nichts gezeigt — kein leeres Hypnogramm,
      // keine Kapseln auf der Grundlinie, die wie ein sehr niedriger
      // Messwert aussähen. Der Kasten unter der Karte sagt warum.
      if (nacht.vonHand == null) ...[
        const SectionHeader('Schlafphasen'),
        wischbar(
          _Karte(
            schluessel: const Key('schlaf-phasen'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Volle Fassung **mit** Spurnamen — der Schirm hat die Breite
                // dafür, anders als die Nachtkarte auf dem Erholung-Schirm.
                //
                // **Und als einziger der drei Orte ablesbar** (#141): Hier
                // steht die Uhrzeitachse, hier liegt die Kopfzeile, hier
                // zeigt ein Halten Zeitspanne, Phase und Dauer. Auf dem
                // Tagschlaf-Schirm führt die Karte darüber schon „1× wach,
                // 4 min", und zwei Stellen mit derselben Zahl laufen
                // auseinander.
                Hypnogramm(
                  session: nacht.nacht.session,
                  kompakt: false,
                  ablesbar: true,
                ),
                const SizedBox(height: 8),
                _PhasenSummen(session: nacht.nacht.session),
              ],
            ),
          ),
        ),

        const SectionHeader('Herzfrequenz im Schlaf'),
        wischbar(
          _Karte(
            schluessel: const Key('schlaf-puls'),
            child: _Spannen(
              datum: nacht.nacht.date,
              art: VitalKind.heartRate,
              // **„Spanne je Abschnitt" steht seit #168 nicht mehr hier**
              // — das sagt der Satz über dem Diagramm, und die Fußzeile
              // sagt, wie lang ein Abschnitt ist. Übrig bleibt, was das
              // Bauteil nicht wissen kann: wozu man hinsieht.
              erklaerung:
                  'Der tiefste Wert der Nacht kommt dem Ruhepuls am '
                  'nächsten.',
            ),
          ),
        ),

        const SectionHeader('Atemfrequenz im Schlaf'),
        wischbar(
          _Karte(
            schluessel: const Key('schlaf-atmung'),
            child: _Spannen(
              datum: nacht.nacht.date,
              art: VitalKind.respiratoryRate,
              erklaerung:
                  'Steigt sie über mehrere Nächte, ist das ein Warnsignal der '
                  'Ampel.',
            ),
          ),
        ),
      ],

      // **„Sieben Nächte" steht bei den Bildern** (#257) — hinter den
      // Diagrammen dieser Nacht, vor den drei Klappzeilen. Und
      // **außerhalb** des Blocks darüber: Auch eine von Hand eingetragene
      // Nacht hat sieben Nächte hinter sich, gemessen wurden die anderen.
      ..._siebenNaechte(ref),

      // **Nur, wenn oben eine ältere Nacht steht.** Sonst stünde der
      // Hinweis ohne Anlass da. Er steht vor den drei Abschnitten, nicht
      // in einem von ihnen: Er gilt für alle drei, und zugeklappt wäre er
      // nicht zu sehen.
      if (daten.zeigtAnderenTag)
        const _VerlaufHinweis(key: Key('schlaf-verlauf-hinweis')),
      ..._zeitabschnitte(
        ref,
        statistik7: statistik7,
        statistik30: statistik30,
        // Das Schlafziel kommt aus den Zielen, nie als Konstante aus dem
        // Quelltext (#152). Die Reihe steht in Stunden, also auch die Linie.
        schlafzielStunden:
            zustand.ziele.schlafzielMinuten / Duration.minutesPerHour,
      ),

      ..._eintragen(context, nacht.nacht.date),

      const Hinweisfuss(
        'Dauer 50, Zubettgehzeit 30, Unterbrechungen 20 Punkte. Die '
        'Zubettgehzeit misst gegen deine eingestellte Schlafenszeit, und '
        'nur später als das Ziel kostet etwas. Bewertet wird der Anteil '
        'der erreichbaren Punkte. Eine Schätzung aus Apple-Health-Werten, '
        'keine medizinische Bewertung.',
        key: Key('schlaf-fussnote'),
      ),
    ];
  }

  /// Der Schirm für einen Tag, für den es **keine** Nacht gibt (#177).
  ///
  /// **Nicht der Leerzustand.** Der sagt „Für diesen Zeitraum liegen keine
  /// Nächte vor" und meint den ganzen Schirm; hier geht es um einen
  /// einzelnen Tag, den jemand angetippt oder angeblättert hat.
  ///
  /// Drei Dinge folgen daraus und stehen so im Entwurf
  /// (`docs/screens/screens/schlaf.js`, Zustand `leerer-tag`):
  ///
  /// - **Die Blätterleiste bleibt stehen** und sagt statt des Fensters
  ///   „keine Nacht" — kein Gedankenstrich, der wie ein fehlender Messwert
  ///   in einer Reihe von Messwerten aussähe.
  /// - **An der Stelle der Score-Karte steht ein Kasten, kein grauer
  ///   Ring.** „Dieselbe Form, nur leer" gilt für Werte, die noch kommen
  ///   können; aus Apple Health kommt für diesen Tag keiner mehr. Ein
  ///   leerer Ring mit drei „entfällt" daneben behauptete eine Messung.
  /// - **Der Eintrag steht oben, auf diesen Tag vorbelegt**, weil er hier
  ///   der einzige Weg ist, der weiterführt — und ohne die Überschrift
  ///   „Fehlt eine Nacht?", die der Kasten darüber schon beantwortet hat.
  ///
  /// Schlafphasen, Puls und Atmung fehlen ganz, wie bei einer von Hand
  /// eingetragenen Nacht: Gemessen wurde nichts, also wird nichts gezeigt.
  /// [daten] ist `null`, wenn der Lauf überhaupt nichts brachte — dann gibt
  /// es auch Verlauf, Schnitte und „Sieben Nächte" nicht.
  List<Widget> _leererTag(
    BuildContext context,
    WidgetRef ref,
    SchlafZustand zustand,
    DateTime tag,
    SchlafAuswahlNotifier auswahl, {
    SchlafDaten? daten,
    bool mitFreigaben = false,
  }) {
    // **Dieselbe Rechnung wie im Zustand**, nicht eine zweite daneben:
    // `SchlafDaten.frueher`/`.spaeter` entstehen aus derselben reinen
    // Funktion auf denselben Eingaben. Sie steht hier, weil es im Zweig
    // `LeerNachLauf` gar kein `SchlafDaten` gibt — der Zeitraum gilt
    // trotzdem.
    final nachbarn = schlafTagNachbarn(
      tag: tag,
      fruehesterTag: zustand.fruehesterTag,
      heute: zustand.heute,
    );
    final aufFrueher = nachbarn.frueher == null
        ? null
        : () => auswahl.blaettere(SchlafBlaettern.frueher);
    final aufSpaeter = nachbarn.spaeter == null
        ? null
        : () => auswahl.blaettere(SchlafBlaettern.spaeter);

    final statistik7 = daten?.statistik7;
    final statistik30 = daten?.statistik30;

    return [
      SchlafWischen(
        aufFrueher: aufFrueher,
        aufSpaeter: aufSpaeter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SchlafBlaetterleiste(
              key: const Key('schlaf-blaetterleiste'),
              datum: tag,
              fenster: 'keine Nacht',
              aufFrueher: aufFrueher,
              aufSpaeter: aufSpaeter,
            ),
            _LeererTagKasten(
              key: const Key('schlaf-leerer-tag'),
              tag: tag,
              mitFreigaben: mitFreigaben,
            ),
          ],
        ),
      ),

      ..._eintragen(context, tag, mitKopf: false),

      if (daten != null) ...[
        // Offen, genau wie im Weg mit Nacht (#257).
        ..._siebenNaechte(ref),

        // **Der Hinweis steht hier ohne Bedingung:** Dieser Weg zeigt
        // immer einen anderen Tag als heute — er entsteht nur, wenn
        // jemand einen leeren Tag angetippt oder angeblättert hat.
        const _VerlaufHinweis(key: Key('schlaf-verlauf-hinweis')),
        ..._zeitabschnitte(
          ref,
          statistik7: statistik7,
          statistik30: statistik30,
          schlafzielStunden:
              zustand.ziele.schlafzielMinuten / Duration.minutesPerHour,
        ),
      ],

      const Hinweisfuss(
        'Dauer 50, Zubettgehzeit 30, Unterbrechungen 20 Punkte. Die '
        'Zubettgehzeit misst gegen deine eingestellte Schlafenszeit, und '
        'nur später als das Ziel kostet etwas. Bewertet wird der Anteil '
        'der erreichbaren Punkte. Eine Schätzung aus Apple-Health-Werten, '
        'keine medizinische Bewertung.',
        key: Key('schlaf-fussnote'),
      ),
    ];
  }

  /// „Sieben Nächte" — **offen**, mit eigener Überschrift (#257).
  ///
  /// Bei #253 war der Abschnitt mit den drei Zeilen zum Zeitverlauf
  /// eingeklappt worden; das war die Auslegung einer Rückfrage, nicht Tims
  /// Wunsch (Tim am 03.11.2026: „Sieben Nächte nicht ein- und ausklappen,
  /// das hast du falsch verstanden"). Er steht deshalb wieder bei den
  /// Bildern der Nacht und nicht zwischen drei Textzeilen.
  ///
  /// Er bezieht sich trotzdem auf **heute** und nicht auf die gezeigte
  /// Nacht (Entscheidung vom 13.10.2026) — deshalb wischt er nicht mit.
  ///
  /// `Key('schlaf-naechte')` sitzt wieder auf der Karte: Den Abschnitt
  /// gibt es nur noch in einem Zustand, also gibt es nichts zu
  /// unterscheiden.
  List<Widget> _siebenNaechte(WidgetRef ref) => [
    const SectionHeader('Sieben Nächte'),
    _Karte(
      schluessel: const Key('schlaf-naechte'),
      child: SchlafNaechteDiagramm(lagen: ref.watch(schlafLagenProvider)),
    ),
  ];

  /// Die drei Abschnitte zum Zeitverlauf — **ganz unten und zugeklappt**
  /// (#253, Tim am 03.11.2026: „sonst ist die Seite so lang").
  ///
  /// Vom kurzen zum langen Zeitraum: sieben Tage bis heute, dreißig Tage
  /// bis heute, Verlauf. Alle drei beziehen sich auf **heute** und nicht
  /// auf die gezeigte Nacht (Entscheidung vom 13.10.2026) — beim Blättern
  /// ändert sich hier keine Zahl, und deshalb stehen sie zusammen.
  ///
  /// **Die Begründung aus #244 ist damit erledigt.** Sie lautete: Der
  /// Verlauf steht hinter allen Diagrammen, weil er zwischen Score und
  /// Hypnogramm die Frage nach *dieser* Nacht mit der Frage nach den
  /// letzten Wochen unterbrach. Zugeklappt sind alle drei gleich hohe
  /// Zeilen; sie unterbrechen nichts mehr, und keine von ihnen steht
  /// zwischen den Diagrammen der Nacht.
  ///
  /// **Jeder trägt den Schlüssel seines Abschnitts** — `schlaf-verlauf`,
  /// `schlaf-statistik-7`, `schlaf-statistik-30`. Er sitzt auf der
  /// Klappzeile und nicht auf dem Inhalt: Den Abschnitt gibt es in jedem
  /// Zustand, den Inhalt nur aufgeklappt.
  ///
  /// **Und jeder braucht ihn auch als [Key]**, nicht nur als Testgriff:
  /// Der Schirm wechselt zwischen zwei Zusammenstellungen (Nacht und
  /// leerer Tag, #177), und ohne Schlüssel ordnete Flutter die offenen
  /// Zustände nach Stelle in der Spalte zu. Ein aufgeklappter Abschnitt
  /// fiele beim Blättern zu — aus Sicht des Nutzers `32`.
  ///
  /// Die Zahl in der zugeklappten Zeile wird **gerechnet, nicht
  /// erfunden**, und zwar je Abschnitt an genau einer Stelle: der Schnitt
  /// aus [schlafStatistikSchnitt], die Spanne aus [schlafVerlaufSpanne].
  /// Gibt es keine, steht dort nichts — keine 0 und kein Strich, der wie
  /// ein Messwert aussähe.
  List<Widget> _zeitabschnitte(
    WidgetRef ref, {
    required SchlafStatistik? statistik7,
    required SchlafStatistik? statistik30,
    required double schlafzielStunden,
  }) {
    // **Gehalten, nicht je Bild gerechnet** (Hausregel 2) — und hier
    // gelesen, nicht im Inhalt: `ref` gehört in `build`, die Baufunktion
    // des Abschnitts läuft später.
    final reihe = ref.watch(schlafTagewerteProvider);
    // Die Teile der gestapelten Balken (#504) — ebenso gehalten und ebenso
    // hier gelesen: `ref` gehört in `build`, nicht in die Baufunktion des
    // Abschnitts, die erst beim Aufklappen läuft.
    final phasen = ref.watch(schlafPhasenTagewerteProvider);

    return [
      if (statistik7 != null)
        KlappAbschnitt(
          key: const Key('schlaf-statistik-7'),
          kopfSchluessel: const Key('schlaf-statistik-7-kopf'),
          inhaltSchluessel: const Key('schlaf-statistik-7-inhalt'),
          // **„bis heute" bleibt im Titel.** Der Block sagte das bisher in
          // seiner eigenen Überschrift; zugeklappt gibt es die nicht mehr,
          // und ein Schnitt ohne seinen Zeitraum ist eine Zahl ohne
          // Aussage.
          titel: 'Letzte $schlafStatistikKurz Nächte bis heute',
          hinweis: 'Ø ${schlafStatistikSchnitt(statistik7)}',
          inhalt: () => SchlafStatistikBlock(statistik: statistik7),
        ),
      if (statistik30 != null)
        KlappAbschnitt(
          key: const Key('schlaf-statistik-30'),
          kopfSchluessel: const Key('schlaf-statistik-30-kopf'),
          inhaltSchluessel: const Key('schlaf-statistik-30-inhalt'),
          titel: 'Letzte $schlafStatistikLang Nächte bis heute',
          hinweis: 'Ø ${schlafStatistikSchnitt(statistik30)}',
          inhalt: () => SchlafStatistikBlock(statistik: statistik30),
        ),
      KlappAbschnitt(
        key: const Key('schlaf-verlauf'),
        kopfSchluessel: const Key('schlaf-verlauf-kopf'),
        inhaltSchluessel: const Key('schlaf-verlauf-inhalt'),
        titel: 'Verlauf',
        hinweis: schlafVerlaufSpanne(reihe),
        inhalt: () => SchlafVerlauf(
          reihe: reihe,
          phasenReihe: phasen,
          schlafzielStunden: schlafzielStunden,
        ),
      ),
    ];
  }

  /// „Fehlt eine Nacht?" — die Tür zum Formular, samt der Zusage darunter,
  /// wohin der Eintrag geht.
  ///
  /// [tag] ist der Aufwachtag, der im Formular vorbelegt wird: die gerade
  /// gezeigte Nacht, im leeren Zustand der heutige Tag. Nicht eine zweite
  /// Uhr im Formular — zwei Stellen, die den Tag unabhängig bestimmen,
  /// waren schon einmal ein Befund.
  ///
  /// [mitKopf] schaltet die Überschrift ab: Auf einem gewählten leeren Tag
  /// hat der Kasten darüber die Frage schon gestellt und beantwortet
  /// (#177).
  List<Widget> _eintragen(
    BuildContext context,
    DateTime tag, {
    bool mitKopf = true,
  }) => [
    if (mitKopf) const SectionHeader('Fehlt eine Nacht?'),
    SchlafEintragenZeile(
      schluessel: const Key('schlaf-eintragen'),
      titel: 'Nacht von Hand eintragen',
      untertitel: 'wenn die Uhr auf dem Nachttisch lag',
      art: SchlafEintragenArt.nacht,
      tag: tag,
    ),
    const Hinweisfuss(
      'Von Hand eingetragene Nächte liegen in dieser App, nicht in Apple '
      'Health — die App schreibt dort nichts hinein. Sie zählen in Dauer '
      'und Bewertung der Nacht; Schlafphasen, Puls und Atmung fehlen '
      'naturgemäß, und Verlauf, Schnitte und „Sieben Nächte" rechnen '
      'weiter über die gemessenen Nächte.',
      key: Key('schlaf-eintragen-hinweis'),
    ),
  ];
}

/// Die Zeile, die das Formular öffnet — auf dem Nacht- wie auf dem
/// Tagschlaf-Schirm dieselbe.
///
/// **Sie springt in keinen Schirm.** Das Formular ist laut Entwurf ein
/// Blatt über dem aktuellen Schirm; `AppRouter` ist hier nicht beteiligt.
class SchlafEintragenZeile extends StatelessWidget {
  const SchlafEintragenZeile({
    super.key,
    required this.schluessel,
    required this.titel,
    required this.untertitel,
    required this.art,
    required this.tag,
  });

  final Key schluessel;
  final String titel;
  final String untertitel;
  final SchlafEintragenArt art;
  final DateTime tag;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);

    return Padding(
      key: schluessel,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      // `Builder`, damit `showCupertinoModalPopup` einen Kontext **unter**
      // dem Navigator bekommt.
      child: Builder(
        builder: (context) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => zeigeSchlafEintragen(context, art: art, tag: tag),
          child: InsetCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.moon_zzz,
                    size: 20,
                    color: CupertinoDynamicColor.resolve(
                      Palette.river,
                      context,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titel,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: ink,
                          ),
                        ),
                        Text(
                          untertitel,
                          style: TextStyle(fontSize: 12, color: muted),
                        ),
                      ],
                    ),
                  ),
                  Icon(CupertinoIcons.chevron_right, size: 14, color: muted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Der Kasten an der Stelle der Score-Karte, wenn es für den gezeigten Tag
/// keine Nacht gibt (#177).
///
/// **Er nennt alle Möglichkeiten und entscheidet keine.** Apple verrät den
/// Lesestatus nicht, also sind „nichts aufgezeichnet" und „nicht
/// freigegeben" nicht unterscheidbar — und dazwischen liegt noch die Uhr,
/// die neben dem Bett lag. Keine davon wird zur Diagnose erhoben.
class _LeererTagKasten extends StatelessWidget {
  const _LeererTagKasten({
    super.key,
    required this.tag,
    required this.mitFreigaben,
  });

  final DateTime tag;

  /// Brachte der Lauf **gar nichts**, bleibt die Freigabefrage offen und
  /// der Weg zu den Health-Einstellungen steht mit dabei. Sie zu
  /// verschlucken, weil gerade ein Tag gewählt ist, wäre die falsche
  /// Reihenfolge.
  final bool mitFreigaben;

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: InsetCard(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Text(
            'Für ${Format.datumAusgeschrieben(kalendertag(tag))} liegt keine '
            'Nacht vor. Die Uhr kann nichts aufgezeichnet haben, sie kann '
            'neben dir gelegen haben, oder der Lesezugriff auf Schlaf ist '
            'nicht freigegeben — Apple verrät den Unterschied nicht. Wenn du '
            'weißt, wie du geschlafen hast, trag die Nacht von Hand ein.'
            '${mitFreigaben ? ' Den Lesezugriff prüfst du in Health unter '
                      'Profil › Apps.' : ''}',
            style: TextStyle(fontSize: 12, height: 1.4, color: muted),
          ),
        ),
      ),
    );
  }
}

/// Der Kasten über einer eingetragenen Nacht — und der Weg zurück.
///
/// **Der Weg zurück gehört dazu, nicht in ein späteres Ticket.** Ein
/// Eintrag legt sich über die gemessene Nacht; ohne „Eintrag entfernen"
/// wäre ein Vertipper endgültig, und die gemessene Nacht darunter für
/// immer verdeckt. Der Entwurf zeigt den Knopf nicht — er zeigt auch keine
/// eingetragene Nacht, die man wieder loswerden will.
///
/// **Ein Kasten, zwei Texte** (#192): Ersetzt der Eintrag die gemessene
/// Nacht oder kommt er zu ihr dazu, ist die Lage verschieden, der Weg
/// zurück aber derselbe. Welcher Text drinsteht, entscheidet der Schirm;
/// die beiden Schlüssel unterscheiden sie.
class _EintragHinweis extends ConsumerWidget {
  const _EintragHinweis({super.key, required this.tag, required this.text});

  final DateTime tag;
  final String text;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: InsetCard(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                text,
                style: TextStyle(fontSize: 12, height: 1.4, color: muted),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: CupertinoButton(
                  key: const Key('schlaf-eintrag-entfernen'),
                  padding: const EdgeInsets.only(top: 6),
                  minimumSize: const Size(44, 36),
                  onPressed: () => ref
                      .read(schlafEintraegeProvider.notifier)
                      .loescheNacht(BerlinCalendar.dayKey(tag)),
                  child: const Text(
                    'Eintrag entfernen',
                    style: TextStyle(fontSize: 13),
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

// ───────────────────────────────────────────────────────────────────────
// Die vier Zweige
// ───────────────────────────────────────────────────────────────────────

/// **Während des Laufs steht nie ein „keine Daten"-Grund** — das ist
/// `docs/todo/01`, in einem Satz.
class _Laden extends StatelessWidget {
  const _Laden({super.key});

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 40),
      child: Text(
        'Schlafdaten werden gelesen …',
        style: TextStyle(fontSize: 13, color: muted),
      ),
    );
  }
}

/// Der Lauf ist fertig und hat nichts gebracht. **Beide Möglichkeiten
/// werden genannt**, denn Apple verrät den Lesestatus nicht.
class _Leer extends StatelessWidget {
  const _Leer({super.key});

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 40),
      child: Text(
        'Für diesen Zeitraum liegen keine Nächte vor. Zwei Erklärungen, '
        'beide möglich: Entweder hat die Uhr nichts aufgezeichnet — oder '
        'der Lesezugriff auf Schlaf ist nicht freigegeben. Apple verrät '
        'nicht, welches von beidem zutrifft. Also beides prüfen: Uhr '
        'nachts tragen, Lesezugriff in den Health-Einstellungen '
        'freigeben.',
        style: TextStyle(fontSize: 13, height: 1.4, color: muted),
      ),
    );
  }
}

/// Ein Fehler ist keine Aussage über die Datenlage — hier steht deshalb
/// gerade **nicht**, dass es keine Daten gäbe.
class _Fehler extends StatelessWidget {
  const _Fehler({super.key});

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 40),
      child: Text(
        'Die Nächte konnten nicht gelesen werden. Das sagt nichts darüber, '
        'ob welche vorliegen — es hat nur gerade nicht geklappt. Später '
        'noch einmal versuchen.',
        style: TextStyle(fontSize: 13, height: 1.4, color: muted),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────
// Bausteine des Schirms
// ───────────────────────────────────────────────────────────────────────

class _Karte extends StatelessWidget {
  const _Karte({required this.schluessel, required this.child});

  final Key schluessel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: schluessel,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: InsetCard(
        child: Padding(padding: const EdgeInsets.all(14), child: child),
      ),
    );
  }
}

class _VerlaufHinweis extends StatelessWidget {
  const _VerlaufHinweis({super.key});

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Text(
        'Oben steht ein anderer Tag. Verlauf und Schnitte beziehen sich '
        'weiter auf heute.',
        style: TextStyle(fontSize: 12, height: 1.35, color: muted),
      ),
    );
  }
}

/// Die Zeile zum Tagschlaf — eine **Tür**, kein Summand. Sie führt auf den
/// eigenen Schirm, nicht tiefer in die Nacht.
class _TagschlafZeile extends StatelessWidget {
  const _TagschlafZeile({
    super.key,
    required this.minuten,
    required this.anzahl,
    required this.router,
  });

  final double minuten;
  final int anzahl;
  final AppRouter router;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => oeffneTagschlaf(router),
        child: InsetCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tagschlaf',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: ink,
                        ),
                      ),
                      Text(
                        anzahl == 1 ? 'eine Phase' : '$anzahl Phasen',
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                    ],
                  ),
                ),
                Text(
                  schlafDauerText(minuten),
                  style: TextStyle(fontSize: 15, color: ink),
                ),
                const SizedBox(width: 6),
                Icon(CupertinoIcons.chevron_right, size: 14, color: muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Die Gesamtzeiten je Phase, unter dem Hypnogramm.
class _PhasenSummen extends StatelessWidget {
  const _PhasenSummen({required this.session});

  final SleepSession session;

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);

    final summen = <SleepStage, double>{};
    for (final abschnitt in session.segments) {
      summen[abschnitt.stage] =
          (summen[abschnitt.stage] ?? 0) +
          abschnitt.end.difference(abschnitt.start).inMicroseconds /
              Duration.microsecondsPerMinute;
    }

    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        for (final phase in SchlafPhasen.reihenfolge)
          if (summen[phase] != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: CupertinoDynamicColor.resolve(
                      SchlafPhasen.farbe(phase),
                      context,
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  '${SchlafPhasen.name(phase)} '
                  '${schlafDauerText(summen[phase]!)}',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ],
            ),
      ],
    );
  }
}

/// Puls oder Atmung einer Nacht.
///
/// **Solange geladen wird, steht ein Ladezeiger** — nicht „nichts
/// gemessen". Das wäre eine andere Aussage, und sie wäre unbelegt.
class _Spannen extends ConsumerWidget {
  const _Spannen({
    required this.datum,
    required this.art,
    required this.erklaerung,
  });

  final DateTime datum;
  final VitalKind art;
  final String erklaerung;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final werte = nachtVitalwerteAusProvider(
      ref.watch(nachtVitalwerteProvider(datum)),
    );

    final Widget inhalt = switch (werte) {
      NochNie<NachtVitalwerte>() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CupertinoActivityIndicator()),
      ),
      LeerNachLauf<NachtVitalwerte>() => Text(
        schlafOhneDaten,
        style: TextStyle(fontSize: 12, color: muted),
      ),
      Fehlgeschlagen<NachtVitalwerte>() => Text(
        'Die Werte dieser Nacht konnten nicht gelesen werden.',
        style: TextStyle(fontSize: 12, color: muted),
      ),
      // **Die Wörter für den Satz über dem Diagramm**, ausgeschrieben wie
      // bei Apple: „Während du geschlafen hast, lag dein Puls bei 58 bis
      // 74 Schlägen pro Minute." Die Kurzform („bpm") gab es, solange die
      // Spanne als Kicker mit Zahl in einer Kopfzeile stand; die ist mit
      // #168 weggefallen — genauso wie die Bezugslinie, die hier bis zum
      // 28.10.2026 den Ruhepuls vom Erholung-Schirm geholt hat.
      Bekannt<NachtVitalwerte>(:final wert) => SchlafSpannenDiagramm(
        spannen: art == VitalKind.heartRate ? wert.puls : wert.atmung,
        farbe: art == VitalKind.heartRate ? Palette.warn : Palette.river,
        groesse: art == VitalKind.heartRate
            ? 'dein Puls'
            : 'deine Atemfrequenz',
        einheit: art == VitalKind.heartRate
            ? 'Schlägen pro Minute'
            : 'Atemzügen pro Minute',
        nachkommastellen: art == VitalKind.heartRate ? 0 : 1,
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          erklaerung,
          style: TextStyle(fontSize: 12, height: 1.35, color: muted),
        ),
        const SizedBox(height: 8),
        inhalt,
      ],
    );
  }
}
