// Der Schirm „Vorläufige Werte" (#307) — der Eingang für Zielgewicht und
// Zieldatum, bis der Erststart (#102, #103) ihn übernimmt. Danach fliegt
// dieser Schirm raus; die Daten bleiben liegen, weil er in die
// **vorhandene** Stammdaten-Tabelle schreibt (#277) und nicht in eine
// eigene.
//
// API und Verhalten sind durch `app/test/shell/vorlaeufige_werte_test.dart`
// verbindlich vorgegeben (siehe dessen Dateikopf) — diese Datei darf die
// Tests ausführen, aber nicht verändern (`CLAUDE.md`, „Wer Tests schreibt,
// schreibt nicht die Implementierung").
//
// Aufbau nach `docs/screens/screens/vorlaeufige-werte.js`, Vorbild für Form
// und Ort ist `healthkit_test_view.dart` — auch ein Schirm, der im
// Mehr-Menü hängt und nicht für die Ewigkeit gedacht ist.
//
// **Kein Datum im Quelltext.** Weder als Konstante noch als Vorgabewert
// noch „nur zum Anschauen" (`CLAUDE.md`, „Keine hartcodierten Ereignisse").
// Das Rad startet auf dem heutigen Tag aus `clockProvider` — und der Tag,
// auf dem es dabei steht, wird **nicht** mitgesichert: Erst eine Drehung
// setzt einen Wert. Sonst wäre „Aufklappen und Sichern" der heimliche Weg
// zu einem Datum, das niemand gewählt hat.
//
// **Seit #410 steht hier auch das Kalorienziel.** Es ist fest und ändert
// sich nur, wenn jemand es ändert — von Hand hier, später über den Coach.
// Das Feld ist durch `app/test/shell/vorlaeufige_werte_kalorienziel_test
// .dart` vorgegeben (Festlegungen des Test-Agenten, nicht von Tim). Zwei
// Punkte darüber hinaus sind **Vorgaben des Koordinators, nicht von Tim
// entschieden**: Ein geleertes Feld lässt sich nicht sichern (zurück zur
// täglichen Rechnung geht es über die App nicht), und der Hinweis unten
// sagt, dass das Körperziel nur in die erste Berechnung eingeht.
//
// **Seit #374 (Karte #433) trägt die Karte des Kalorienziels eine zweite
// Zeile „Aufteilung auf Mahlzeiten"** (V14 der Spec
// `docs/superpowers/specs/2026-11-10-mahlzeiten-aufteilung-design.md`,
// Entwurf `vorlaeufige-werte.js`, Zustand `mit-aufteilung`). Sie
// zeigt die heute geltende Aufteilung und öffnet `aufteilung` über den
// Router — darum nimmt die Seite ihn jetzt entgegen.
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../data/kalorienziele.dart';
import '../data/mahlzeit_aufteilungen.dart';
import '../data/stammdaten.dart';
import '../design/formatierung.dart';
import '../design/glas_abstand.dart';
import '../design/grosse_ueberschrift.dart';
import '../design/hinweisfuss.dart';
import '../design/inset_card.dart';
import '../design/palette.dart';
import '../design/platzhalter.dart';
import '../design/section_header.dart';
import '../ernaehrung/aufteilung_view.dart';
import '../health/health_provider.dart';
import 'mess_abschnitte.dart' show datumZumAnzeigen;
import 'router.dart';
import 'ziele.dart';

/// Öffnet `vorlaeufige-werte` auf dem Stapel des **aktuell gewählten** Tabs
/// — die eine Stelle, die das weiß (wie `oeffneErholungWerte`,
/// `oeffneKoerper`, `oeffneMessungen`).
///
/// `AppTarget.aktuell`, nicht `.detail`: Ein Schirm, der im Menü unter
/// einem bestimmten Tab einsortiert ist, wechselt trotzdem nie dorthin —
/// sonst führte „zurück" in ein Menü, das der Nutzer nie geöffnet hat
/// (`CLAUDE.md`).
///
/// Reicht [router] an die Seite durch, damit die Zeile „Aufteilung auf
/// Mahlzeiten" über `oeffneAufteilung` springen kann (V14).
void oeffneVorlaeufigeWerte(AppRouter router) => router.open(
  AppTarget.aktuell((context) => VorlaeufigeWerteSeite(router: router)),
);

/// Der Rahmen: Gerüst und Navigationsleiste um [VorlaeufigeWerteView].
///
/// **Kein eigener `Navigator`** — den stellt `RootView`. Zwei
/// verschachtelte Stapel schließen die gepushte Seite sofort wieder
/// (`CLAUDE.md`).
class VorlaeufigeWerteSeite extends StatelessWidget {
  const VorlaeufigeWerteSeite({super.key, this.router});

  /// Für die Sprünge aus dem Schirm. Ohne ihn steht die Zeile
  /// „Aufteilung auf Mahlzeiten" da, führt aber nirgendwohin.
  final AppRouter? router;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoDynamicColor.resolve(Palette.bg, context),
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Vorläufige Werte'),
      ),
      child: VorlaeufigeWerteView(router: router),
    );
  }
}

/// Der Schirm selbst — ohne Gerüst, ohne Leiste, ohne Navigator.
///
/// **Er besorgt seine Daten selbst** ([stammdatenProvider]): Jeder Schirm
/// ist aus jedem Tab erreichbar, niemand darf sich darauf verlassen, dass
/// eine Übersicht vorher geladen hat.
class VorlaeufigeWerteView extends ConsumerStatefulWidget {
  const VorlaeufigeWerteView({super.key, this.router});

  final AppRouter? router;

  @override
  ConsumerState<VorlaeufigeWerteView> createState() =>
      _VorlaeufigeWerteZustand();
}

class _VorlaeufigeWerteZustand extends ConsumerState<VorlaeufigeWerteView> {
  final _gewicht = TextEditingController();

  /// Das Kalorienziel in ganzen kcal (#410).
  final _kcal = TextEditingController();

  /// Was im Kalorienzielfeld **stand**, als die Vorbelegung kam — als Text,
  /// nicht als Zahl dahinter: 2.617,4 kcal stehen als „2617" da, und ein
  /// „Sichern" wegen des Zielgewichts darf daraus kein Ziel „von Hand"
  /// machen. Die Herleitung behauptete sonst eine Entscheidung, die
  /// niemand getroffen hat.
  String _kcalVorher = '';

  /// Wie [_uebernommen], für die Historie des Kalorienziels — sie kommt
  /// aus einem anderen Provider und kann zu einem anderen Zeitpunkt da
  /// sein.
  bool _kcalUebernommen = false;

  /// Das Zieldatum als **ISO-Tagesstring**, so wie es in der Tabelle
  /// liegt. `null` heißt hier schlicht „nicht eingetragen" — hinter diesem
  /// Schirm steht kein Lauf aus Apple Health, der leer ausgehen könnte,
  /// also gilt `Messwert<T>` nicht (siehe `stammdaten.dart`).
  String? _zieldatum;

  /// Das Rad ist erst nach dem Antippen der Zeile da. Ein immer sichtbares
  /// Rad stünde beim leeren Stand auf *heute* und sähe aus wie ein Wert.
  bool _radOffen = false;

  /// Die Vorbelegung aus der Tabelle kommt **genau einmal**. Danach gehört
  /// das Formular dem Nutzer: Ein zweiter Lesevorgang, der mitten im Tippen
  /// das Feld überschreibt, nimmt ihm seine Eingabe weg.
  bool _uebernommen = false;

  bool _laeuft = false;

  @override
  void dispose() {
    // Kein `ref` hier (`avoid_ref_inside_state_dispose`) — nur der
    // Controller, der dieser Zustand selbst angelegt hat.
    _gewicht.dispose();
    _kcal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final zustand = ref.watch(stammdatenProvider);

    // Die Vorbelegung über `ref.listen` statt über `initState`: `ref`
    // gehört in `build` und in Notifier (`CLAUDE.md`), und der erste
    // Lesevorgang ist noch nicht fertig, wenn dieser Schirm zum ersten Mal
    // baut.
    ref.listen<AsyncValue<Stammdaten>>(stammdatenProvider, (_, jetzt) {
      final wert = jetzt.value;
      if (_uebernommen || wert == null) return;
      setState(() => _uebernimm(wert));
    });

    final (:laedt, :stammdaten) = stammdatenAusProvider(zustand);
    // Der Fall, in dem der Stand schon beim ersten Aufbau dasteht — dann
    // meldet sich `ref.listen` nie. Hier ist das Feld noch nicht gebaut,
    // also hört niemand auf den Controller und niemand wird mitten im
    // Aufbau als „neu zu bauen" markiert.
    if (!_uebernommen && !laedt) _uebernimm(stammdaten);

    // Dasselbe für das Kalorienziel. Die Festlegung, die **heute** gilt —
    // der Berliner Tag aus `clockProvider`.
    final heute = BerlinCalendar.dayKey(ref.watch(clockProvider)());
    ref.listen<AsyncValue<List<KalorienzielFestlegung>>>(
      kalorienzieleProvider,
      (_, jetzt) {
        if (_kcalUebernommen || jetzt.isLoading) return;
        setState(() => _uebernimmKcal(jetzt.value ?? const [], heute));
      },
    );
    final ziele = ref.watch(kalorienzieleProvider);
    // Eine unlesbare Historie lässt das Feld leer stehen, statt den Schirm
    // zu sperren — Zielgewicht und Zieldatum bleiben sicherbar.
    final zieleLaden = ziele.isLoading;
    if (!_kcalUebernommen && !zieleLaden) {
      _uebernimmKcal(ziele.value ?? const [], heute);
    }

    return SingleChildScrollView(
      padding: GlasAbstand.of(context) + const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const GrosseUeberschrift(
            'Vorläufige Werte',
            einordnung: 'Körperziel',
          ),
          const _VorlaeufigkeitsHinweis(key: Key('vorlaeufige-werte-hinweis')),
          const SectionHeader('Körperziel'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: InsetCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _zielgewichtZeile(context),
                  _trennlinie(context),
                  _zieldatumZeile(context),
                  if (_radOffen) _rad(),
                ],
              ),
            ),
          ),
          // Eine eigene Karte, aber **ohne eigene Gruppenüberschrift**: Die
          // Zeile benennt sich selbst. Mit Überschrift rutschte „Sichern"
          // bei offenem Rad unter den Rand der 800 × 600 großen Testfläche,
          // auf der `vorlaeufige_werte_test.dart` ohne zu scrollen tippt.
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: InsetCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _kalorienzielZeile(context),
                  _trennlinie(context),
                  // Neben dem Ziel, weil sie aus ihm rechnet (#374).
                  _aufteilungZeile(context, heute),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: CupertinoButton.filled(
              key: const Key('vorlaeufige-werte-sichern'),
              onPressed:
                  laedt ||
                      zieleLaden ||
                      _laeuft ||
                      !_gewichtGueltig ||
                      !_kcalGueltig
                  ? null
                  : _sichere,
              child: const Text('Sichern'),
            ),
          ),
          // Seit #410 ist das Kalorienziel fest: Das Körperziel geht nur in
          // die **erste** Berechnung ein. Der frühere Satz („bestimmt den
          // Aufschlag") stimmte danach nicht mehr — Neufassung als Vorgabe
          // des Koordinators, nicht von Tim entschieden.
          const Hinweisfuss(
            'Zielgewicht und Zieldatum gehen nur in die erste Berechnung '
            'deines Kalorienziels ein (Aufschlag höchstens 100 bis 400 kcal '
            'am Tag; ohne sie rechnet die App ohne Aufschlag). Danach bleibt '
            'das Ziel fest, bis du es hier änderst. Alle Angaben sind '
            'allgemeine Schätzungen, keine medizinische Bewertung.',
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // Zeilen
  // ------------------------------------------------------------------

  Widget _zielgewichtZeile(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
      child: Row(
        children: [
          const Expanded(child: Text('Zielgewicht')),
          SizedBox(
            width: 104,
            child: CupertinoTextField.borderless(
              key: const Key('vorlaeufige-werte-zielgewicht-feld'),
              controller: _gewicht,
              // Die leere Anzeige sagt „–/–", nicht „0": Eine Null
              // behauptete ein Ziel von null Kilogramm (Fehler `01` in
              // neuer Verpackung).
              placeholder: ohneWert,
              textAlign: TextAlign.end,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              // Nur, damit „Sichern" mitbekommt, ob gerade etwas
              // Unlesbares im Feld steht.
              onChanged: (_) => setState(() {}),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Text('kg', style: TextStyle(color: muted)),
          ),
        ],
      ),
    );
  }

  Widget _kalorienzielZeile(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
      child: Row(
        children: [
          const Expanded(child: Text('Kalorienziel')),
          SizedBox(
            width: 104,
            child: CupertinoTextField.borderless(
              key: const Key('vorlaeufige-werte-kalorienziel-feld'),
              controller: _kcal,
              // Ohne Festlegung „–/–", **nicht** die gerechnete Zahl: Die
              // stünde da wie ein festes Ziel, das es nicht gibt.
              placeholder: ohneWert,
              textAlign: TextAlign.end,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Text('kcal', style: TextStyle(color: muted)),
          ),
        ],
      ),
    );
  }

  /// „Aufteilung auf Mahlzeiten" (V14): die heute geltende Aufteilung als
  /// „25 · 35 · 30 · 10 %", ohne eine „–/–" — **nicht** der Startwert, der
  /// gilt erst nach dem Sichern (Entscheidung 1). Solange die Historie
  /// nicht gelesen ist, steht eine graue Form (`01`).
  Widget _aufteilungZeile(BuildContext context, String heute) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final historie = ref.watch(mahlzeitAufteilungenProvider);
    final geltend = historie.hasValue
        ? geltendeAufteilung(historie.value!, heute)
        : null;
    final router = widget.router;
    final wertStil = TextStyle(color: muted);

    final Widget wert;
    final String vorlesen;
    if (!historie.hasValue) {
      wert = Platzhalter(beispiel: '25 · 35 · 30 · 10 %', stil: wertStil);
      vorlesen = 'Aufteilung auf Mahlzeiten, wird geladen';
    } else if (geltend == null) {
      wert = Text(ohneWert, style: wertStil);
      vorlesen = 'Aufteilung auf Mahlzeiten, keine Werte';
    } else {
      final text =
          '${geltend.fruehstueck} · ${geltend.mittag} · ${geltend.abend} · '
          '${geltend.snack} %';
      wert = Text(text, style: wertStil);
      vorlesen =
          'Aufteilung auf Mahlzeiten, Frühstück ${geltend.fruehstueck}, '
          'Mittag ${geltend.mittag}, Abend ${geltend.abend}, '
          'Snack ${geltend.snack} Prozent';
    }

    return GestureDetector(
      key: const Key('vorlaeufige-werte-aufteilung'),
      behavior: HitTestBehavior.opaque,
      onTap: router == null ? null : () => oeffneAufteilung(router),
      child: Semantics(
        button: router != null,
        label: vorlesen,
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              const Expanded(child: Text('Aufteilung auf Mahlzeiten')),
              wert,
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(
                  CupertinoIcons.chevron_forward,
                  size: 14,
                  color: muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _zieldatumZeile(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final iso = _zieldatum;

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            key: const Key('vorlaeufige-werte-zieldatum'),
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _radOffen = !_radOffen),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 0, 12),
              child: Row(
                children: [
                  const Expanded(child: Text('Zieldatum')),
                  KeyedSubtree(
                    key: const Key('vorlaeufige-werte-zieldatum-wert'),
                    child: Text(
                      // Über den gemeinsamen Formatierer mit fest
                      // gesetzter Sprache, nie über `DateTime.format…`:
                      // Auf einem englisch eingestellten Gerät stünde
                      // sonst „6. Oct" mitten im deutschen Text.
                      iso == null
                          ? ohneWert
                          : Format.tag(datumZumAnzeigen(iso)),
                      // Der Vorlesetext nennt den Zustand, nicht das
                      // Zeichen (`CLAUDE.md`).
                      semanticsLabel: iso == null
                          ? 'Zieldatum, keine Werte'
                          : null,
                      style: TextStyle(color: muted),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // **Steht in jedem Zustand an derselben Stelle**, nur ohne
        // Wirkung, solange es nichts zu leeren gibt: Ein Knopf, der
        // auftaucht, sobald ein Wert da ist, verschöbe die Zeile genau
        // dann, wenn sie sich ohnehin ändert.
        CupertinoButton(
          key: const Key('vorlaeufige-werte-zieldatum-loeschen'),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: const Size(44, 44),
          onPressed: iso == null
              ? null
              : () => setState(() {
                  _zieldatum = null;
                  // Ein offenes Rad, das weiter auf dem gerade
                  // gelöschten Tag steht, sähe aus wie ein Wert.
                  _radOffen = false;
                }),
          child: Icon(
            CupertinoIcons.clear_circled_solid,
            size: 18,
            semanticLabel: 'Zieldatum löschen',
            color: muted.withValues(alpha: iso == null ? 0.3 : 1),
          ),
        ),
      ],
    );
  }

  /// Das Rad hängt **im Schirm**, nicht in einem Blatt mit eigenem
  /// „Fertig" — das wäre eine zweite Sicherungsstufe neben „Sichern".
  Widget _rad() {
    return SizedBox(
      height: 180,
      child: CupertinoDatePicker(
        mode: CupertinoDatePickerMode.date,
        initialDateTime: _radStart,
        // **Der Tagesstring kommt aus den Kalenderfeldern des Rades.**
        // Wer stattdessen den Zeitpunkt nach UTC dreht, verschiebt den Tag
        // um einen (`CLAUDE.md`, „Der Datumsschlüssel ist der
        // ISO-Tagesstring").
        onDateTimeChanged: (wert) =>
            setState(() => _zieldatum = _alsTagesstring(wert)),
      ),
    );
  }

  Widget _trennlinie(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 14),
    child: Container(
      height: 1,
      color: CupertinoDynamicColor.resolve(Palette.line, context),
    ),
  );

  // ------------------------------------------------------------------
  // Werte hin und her
  // ------------------------------------------------------------------

  void _uebernimm(Stammdaten stand) {
    _uebernommen = true;
    _gewicht.text = _alsText(stand.zielgewichtKg);
    _zieldatum = stand.zieldatum;
  }

  /// Die Festlegung, die heute gilt, als ganze kcal — ohne Festlegung leer.
  void _uebernimmKcal(List<KalorienzielFestlegung> historie, String heute) {
    _kcalUebernommen = true;
    final gilt = geltendeFestlegung(historie, heute);
    _kcalVorher = gilt == null ? '' : gilt.kcal.round().toString();
    _kcal.text = _kcalVorher;
  }

  /// Ganze kcal, nur Ziffern. Ein Punkt wäre mehrdeutig — „2.650" als
  /// Tausenderpunkt oder als 2,65 kcal.
  int? _kcalZahl(String text) => int.tryParse(text.trim());

  /// Leer ist nur gültig, wenn es schon leer **war**: Ein geleertes Feld
  /// hieße, wieder täglich zu rechnen, und das geht über die App nicht
  /// (Vorgabe des Koordinators, nicht von Tim). Unlesbares und Zahlen ≤ 0
  /// lassen sich nicht sichern — ein Ziel von 0 stünde sofort auf
  /// „erreicht".
  bool get _kcalGueltig {
    final roh = _kcal.text.trim();
    if (roh.isEmpty) return _kcalVorher.isEmpty;
    final zahl = _kcalZahl(roh);
    return zahl != null && zahl > 0;
  }

  /// Wo das Rad aufgeht: beim eingetragenen Tag, sonst beim heutigen.
  ///
  /// **Aus `clockProvider`, nicht aus einer Konstante** — und der Tag
  /// bleibt eine bloße Radstellung, bis jemand dreht (siehe Dateikopf).
  DateTime get _radStart {
    final iso = _zieldatum;
    final tag = iso == null
        ? kalendertag(ref.read(clockProvider)())
        : datumZumAnzeigen(iso);
    // Als Ortszeit: `CupertinoDatePicker` rechnet intern mit lokalen
    // Kalendertagen, ein UTC-Träger führte dort zu Rundungen über die
    // Tagesgrenze.
    return DateTime(tag.year, tag.month, tag.day);
  }

  /// Der Tagesstring aus Jahr, Monat und Tag — ohne Umweg über einen
  /// Zeitpunkt.
  String _alsTagesstring(DateTime wert) =>
      '${wert.year.toString().padLeft(4, '0')}-'
      '${wert.month.toString().padLeft(2, '0')}-'
      '${wert.day.toString().padLeft(2, '0')}';

  /// Deutsche Schreibweise, und ohne die „,0" bei einem runden Wert.
  /// Leer bleibt leer — **keine 0**.
  String _alsText(double? kg) {
    if (kg == null) return '';
    final roh = kg == kg.roundToDouble()
        ? kg.round().toString()
        : kg.toString();
    return roh.replaceAll('.', ',');
  }

  /// Komma und Punkt gelten beide als Dezimaltrennzeichen: Die deutsche
  /// Ziffern-Tastatur liefert das Komma, und ein Feld, das nur den Punkt
  /// kennt, machte aus „81,4" entweder nichts oder 814.
  double? _alsZahl(String text) {
    final roh = text.trim().replaceAll(',', '.');
    if (roh.isEmpty) return null;
    return double.tryParse(roh);
  }

  /// Leer ist gültig — gemeint ist dann „kein Zielgewicht". Unlesbares ist
  /// es nicht: Ein Tippfehler darf nicht als „gelöscht" durchgehen.
  bool get _gewichtGueltig {
    final roh = _gewicht.text.trim();
    if (roh.isEmpty) return true;
    final zahl = _alsZahl(roh);
    return zahl != null && zahl > 0;
  }

  /// Schreibt den Stand.
  ///
  /// **Gelesen, dann geändert, dann geschrieben.**
  /// `StammdatenRepository.schreibe` setzt alle vier Felder; ein frisch
  /// gebautes `Stammdaten(zielgewichtKg: …, zieldatum: …)` löschte
  /// Körpergröße und Geburtsjahr lautlos — also genau das, was der
  /// Health-Lauf (#306) gerade gefüllt hat.
  ///
  /// **`null` heißt `null`.** Ein geleertes Feld wird geleert; `kopieMit`
  /// taugt dafür nicht, weil es `null` als „nicht gemeint" liest.
  Future<void> _sichere() async {
    setState(() => _laeuft = true);
    final notifier = ref.read(stammdatenProvider.notifier);
    final bisher = ref.read(stammdatenProvider).value ?? const Stammdaten();

    // Vor dem ersten `await` gelesen — danach kann der Schirm schon weg
    // sein.
    final ziele = ref.read(kalorienzieleProvider.notifier);
    final kcalText = _kcal.text.trim();
    // **Gesichert wird nur, was sich geändert hat** — verglichen mit dem,
    // was im Feld stand (siehe [_kcalVorher]).
    final kcalNeu = kcalText == _kcalVorher ? null : _kcalZahl(kcalText);

    try {
      await notifier.setze(
        Stammdaten(
          groesseCm: bisher.groesseCm,
          geburtsjahr: bisher.geburtsjahr,
          zielgewichtKg: _alsZahl(_gewicht.text),
          zieldatum: _zieldatum,
        ),
      );
      if (kcalNeu != null) {
        // Ab heute, von Hand — frühere Tage behalten ihr Ziel.
        await ziele.setzeVonHand(kcalNeu.toDouble());
        _kcalVorher = kcalText;
      }
    } finally {
      if (mounted) setState(() => _laeuft = false);
    }
  }
}

/// Der Satz, der sagt, dass dieser Eingang nur bis zum Erststart besteht —
/// Dart-Entsprechung von `noteBox('neutral', …)` aus
/// `docs/screens/components.js`.
///
/// **Steht in jedem Zustand**, auch wenn Werte da sind: Vorläufig bleibt
/// der Schirm trotzdem. Ohne ihn sähe er in drei Monaten aus wie eine
/// Funktion, die jemand vergessen hat.
class _VorlaeufigkeitsHinweis extends StatelessWidget {
  const _VorlaeufigkeitsHinweis({super.key});

  @override
  Widget build(BuildContext context) {
    final ton = CupertinoDynamicColor.resolve(Palette.bib, context);
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: ton.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border(left: BorderSide(color: ton, width: 3)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(11, 10, 12, 10),
          child: Text(
            'Vorläufig: Diese beiden Werte fragt später der Erststart ab. '
            'Bis dahin trägst du sie hier ein — und kannst sie hier auch '
            'wieder ändern.',
            style: TextStyle(fontSize: 13, height: 1.35, color: ink),
          ),
        ),
      ),
    );
  }
}
