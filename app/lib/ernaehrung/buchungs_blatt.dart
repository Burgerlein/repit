// Das Buchungsblatt (#285) — `docs/screens/screens/erfassen.js`, Zustände
// `produkt` und `aendern`. **Ein** Blatt für beides: Zwei Wege zur selben
// Menge laufen auseinander.
//
// API und Verhalten sind durch `app/test/ernaehrung/erfassen_view_test.dart`
// verbindlich vorgegeben (siehe dessen Dateikopf) — diese Datei darf die
// Tests ausführen, aber nicht verändern (`CLAUDE.md`, „Wer Tests schreibt,
// schreibt nicht die Implementierung").
//
// **Die Portion ist die eigentliche Frage**, nicht das Lebensmittel — hier
// entstehen die meisten Fehler beim Tracken. Deshalb steht die Menge oben
// und groß.
//
// **Das Blatt schließt sich nicht selbst**, es meldet `onFertig`.
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../data/portion.dart';
import '../design/inset_card.dart';
import '../design/palette.dart';
import '../design/platzhalter.dart';
import '../design/zahlen.dart';
import 'erfassen_bausteine.dart';
import 'erfassen_formular.dart';
import 'erfassen_provider.dart';
import 'portion_dialog.dart';
import 'portions_abruf.dart';
import 'portions_text.dart';
import 'portions_waehler.dart';
import 'wann_auswahl.dart';

/// Das Buchungsblatt — „Portion wählen" und „Eintrag ändern".
///
/// Bringt **keinen** eigenen `CupertinoPageScaffold` mit — den stellt,
/// wer es zeigt.
class BuchungsBlatt extends ConsumerStatefulWidget {
  const BuchungsBlatt({
    super.key,
    required this.formular,
    this.abruf,
    this.onFertig,
    this.onGebucht,
  });

  /// Der Anfangszustand: aus einer Vorlage (`BuchungsFormular.neu`) oder
  /// aus einem gebuchten Eintrag (`BuchungsFormular.fuer`).
  final BuchungsFormular formular;

  /// Wonach bei Open Food Facts gefragt wird — `brauchtAbruf(vorlage)`
  /// dessen, der das Blatt öffnet (#399). `null` heißt: Das Blatt fragt
  /// nicht. Das Formular selbst kann das nicht entscheiden: Bei einem
  /// übernommenen Produkt kennt es weder Strichcode noch, ob schon gefragt
  /// wurde.
  final PortionsQuelle? abruf;

  /// Gerufen, nachdem gebucht, geändert oder gelöscht wurde.
  final VoidCallback? onFertig;

  /// Gerufen mit der ID des neuen Eintrags, **nur nach einer neuen
  /// Buchung** und vor [onFertig] — für das Band „Rückgängig" der Suche
  /// (#440, V26, V27).
  final void Function(int eintragId)? onGebucht;

  @override
  ConsumerState<BuchungsBlatt> createState() => _BuchungsBlattZustand();
}

class _BuchungsBlattZustand extends ConsumerState<BuchungsBlatt> {
  late BuchungsFormular _formular = widget.formular;

  /// Die beiden **vorbelegten** Felder — Menge bei „g", Anzahl bei einer
  /// Portion. Ein Knopf (−, +, „g") ändert das Formular, und das Feld
  /// zieht nach ([_gleicheFelderAn]); ein Tastendruck geht den
  /// umgekehrten Weg.
  late final TextEditingController _menge = TextEditingController(
    text: widget.formular.mengeText,
  );
  late final TextEditingController _anzahl = TextEditingController(
    text: widget.formular.anzahlText,
  );

  bool _laeuft = false;

  @override
  void initState() {
    super.initState();
    _hoereAbruf();
  }

  /// Ein neues [BuchungsBlatt.formular] an derselben Stelle im Baum ist
  /// ein **anderes** Blatt — „Portion wählen" wird zu „Eintrag ändern",
  /// oder ein zweiter Eintrag wird angetippt.
  ///
  /// Ohne das bliebe der Zustand des vorigen stehen: `late _formular`
  /// läuft genau einmal, und das Blatt zeigte weiter die alte Menge, die
  /// alte Mahlzeit und keinen „Löschen"-Knopf.
  @override
  void didUpdateWidget(BuchungsBlatt alt) {
    super.didUpdateWidget(alt);
    if (identical(widget.formular, alt.formular) && widget.abruf == alt.abruf) {
      return;
    }
    _formular = widget.formular;
    _gleicheFelderAn();
    _laeuft = false;
    if (widget.abruf != alt.abruf) _hoereAbruf();
  }

  @override
  void dispose() {
    _menge.dispose();
    _anzahl.dispose();
    super.dispose();
  }

  ProviderSubscription<PortionsAbruf>? _abo;

  /// Hört auf den Abruf — **nur**, wenn das Blatt fragt. Eine Antwort
  /// fließt über `mitAbruf` ins Formular, **die Wahl bleibt**: Wer schon
  /// 30 g getippt hat, behält 30 g (Spec, „Leerzustände").
  ///
  /// `listenManual` statt `ref.listen` in `build`: Der Behälter ist
  /// `autoDispose`, und das Abonnement hält ihn genau so lange, wie das
  /// Blatt offen ist — „eine Anfrage je Öffnen".
  void _hoereAbruf() {
    _abo?.close();
    _abo = null;
    final quelle = widget.abruf;
    if (quelle == null) return;
    _abo = ref.listenManual<PortionsAbruf>(portionsAbrufProvider(quelle), (
      _,
      neu,
    ) {
      if (neu is AbrufFertig) _setze(_formular.mitAbruf(neu));
    }, fireImmediately: true);
  }

  /// Setzt das Formular und zieht die Felder nach.
  void _setze(BuchungsFormular formular) {
    if (!mounted) return;
    setState(() {
      _formular = formular;
      _gleicheFelderAn();
    });
  }

  /// Nur wenn der Text abweicht — sonst spränge beim Tippen der Cursor.
  void _gleicheFelderAn() {
    if (_menge.text != _formular.mengeText) _menge.text = _formular.mengeText;
    if (_anzahl.text != _formular.anzahlText) {
      _anzahl.text = _formular.anzahlText;
    }
  }

  bool get _aendert => _formular.bearbeitetId != null;

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoDynamicColor.resolve(Palette.bg, context);
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final tastatur = MediaQuery.of(context).viewInsets.bottom;
    final quelle = widget.abruf;
    final abruf = quelle == null
        ? null
        : ref.watch(portionsAbrufProvider(quelle));

    return ColoredBox(
      color: bg,
      child: DefaultTextStyle(
        style: TextStyle(color: ink, fontSize: 15),
        child: Column(
          children: [
            ErfassenKopf(
              titel: _formular.name,
              sichernText: _aendert ? 'Sichern' : 'Buchen',
              sichernSchluessel: const Key('buchung-sichern'),
              aufAbbrechen: _laeuft ? null : () => Navigator.maybePop(context),
              aufSichern: _formular.kannBuchen && !_laeuft ? _sichere : null,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 24 + tastatur),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _inhalt(context, abruf),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _inhalt(BuildContext context, PortionsAbruf? abruf) => [
    const ErfassenKapitel('Portion'),
    PortionsWaehler(
      formular: _formular,
      abruf: abruf,
      mengeController: _menge,
      anzahlController: _anzahl,
      aufMenge: (text) => setState(() => _formular = _formular.mitMenge(text)),
      aufAnzahl: (text) =>
          setState(() => _formular = _formular.mitAnzahl(text)),
      aufGramm: _laeuft ? null : () => _setze(_formular.waehleGramm()),
      aufPortion: _laeuft ? null : _waehle,
      aufPlus: _laeuft ? null : () => _setze(_formular.plus()),
      aufMinus: _laeuft ? null : () => _setze(_formular.minus()),
      // **Im Ändern-Blatt** weder Langdruck noch „+ Portion": Eine neue
      // Portion gehört an das Lebensmittel, nicht an einen gebuchten
      // Eintrag (Spec, „Das Ändern-Blatt").
      aufLangdruck: _laeuft || _aendert ? null : _aendere,
      aufNeu: _laeuft || _aendert ? null : _legeAn,
    ),

    const ErfassenKapitel('Dafür'),
    _Naehrwertblock(
      key: const Key('buchung-naehrwerte'),
      werte: _formular.naehrwerte,
    ),
    // Wofür die Werte gelten — einzeilig, in jedem Zustand da.
    ErfassenHinweis(
      'für ${switch (_formular.mengeG) {
        final m? => portionsMenge(m, fluessig: _formular.fluessig),
        null => ohneWert,
      }}',
    ),

    const ErfassenKapitel('Wann'),
    InsetCard(
      child: Column(
        children: [
          ErfassenWertZeile(
            key: const Key('buchung-mahlzeit'),
            titel: 'Mahlzeit',
            wert: mahlzeitText(_formular.mahlzeit),
            aufTippen: _laeuft ? null : () => _waehleMahlzeit(context),
          ),
          const ErfassenTrenner(),
          ErfassenWertZeile(
            key: const Key('buchung-uhrzeit'),
            titel: 'Uhrzeit',
            wert: uhrzeitText(_formular.minutenSeitMitternacht),
            aufTippen: _laeuft ? null : () => _waehleUhrzeit(context),
          ),
        ],
      ),
    ),

    // **Der Tag steht ohne Winkel da.** Er ist der offene Tag des Schirms
    // dahinter und hier nicht änderbar; eine Zeile mit Winkel verspräche
    // eine Auswahl, die es nicht gibt (Entwurf, 04.11.2026).
    ErfassenHinweis(
      _aendert
          ? 'Die Nährwerte dieses Eintrags sind die vom Tag des Buchens. '
                'Wer das Lebensmittel später korrigiert, ändert damit nicht '
                'rückwirkend die Vergangenheit. Gebucht bleibt der '
                '${_formular.tagesSchluessel}.'
          : 'Gebucht wird auf den offenen Tag (${_formular.tagesSchluessel}), '
                'nicht auf heute. Die Nährwerte werden jetzt festgehalten — '
                'eine spätere Korrektur des Lebensmittels ändert diesen '
                'Eintrag nicht mehr.',
    ),

    if (_aendert)
      Padding(
        padding: const EdgeInsets.only(top: 14),
        child: CupertinoButton(
          key: const Key('buchung-loeschen'),
          color: CupertinoDynamicColor.resolve(
            Palette.warn,
            context,
          ).withValues(alpha: 0.16),
          onPressed: _laeuft ? null : _loesche,
          child: Text(
            'Eintrag löschen',
            style: TextStyle(
              color: CupertinoDynamicColor.resolve(Palette.warn, context),
            ),
          ),
        ),
      ),
  ];

  /// Ein Tipp auf die **schon gewählte** Portion tut nichts. `waehlePortion`
  /// setzt die Anzahl auf 1 (Entscheidung 9) — gemeint ist das für den
  /// Wechsel, nicht für einen zweiten Tipp auf dasselbe.
  void _waehle(Portion p) {
    if (_formular.portion == p) return;
    _setze(_formular.waehlePortion(p));
  }

  /// „+ Portion" — der Dialog `portion-anlegen`. Danach ist die neue
  /// Portion gewählt, Anzahl 1.
  ///
  /// **Gespeichert wird nur, was schon gespeichert ist** (V3): Ein noch
  /// nicht übernommener Treffer behält die Portion im Formular, und sie
  /// geht beim Buchen mit dem Produkt in die Tabelle — „Abbrechen"
  /// verwirft beides.
  Future<void> _legeAn() async {
    final ergebnis = await zeigePortionDialog(
      context,
      lebensmittelName: _formular.name,
      fluessig: _formular.fluessig,
    );
    if (ergebnis is! PortionGesichert || !mounted) return;
    final neu = Portion(name: ergebnis.name, mengeG: ergebnis.mengeG);
    final id = _formular.lebensmittelId;
    if (id == null) {
      _setze(_formular.mitNeuerPortion(neu));
      return;
    }
    final vorher = {for (final p in _formular.portionen) p.id};
    final liste = await _schreibe(
      (erfassen) => erfassen.legePortionAn(id, neu),
    );
    if (liste == null) return;
    var formular = _formular.mitPortionen(liste);
    for (final p in liste) {
      if (!vorher.contains(p.id)) {
        formular = formular.waehlePortion(p);
        break;
      }
    }
    _setze(formular);
  }

  /// Langdruck auf eine Portion — der Dialog `portion-aendern`. Geändert
  /// bleibt sie gewählt samt Anzahl, gelöscht springt die Wahl auf „g"
  /// mit der bisherigen Menge (V11). Gebuchte Einträge behalten ihren
  /// Schnappschuss.
  Future<void> _aendere(Portion p) async {
    final ergebnis = await zeigePortionDialog(
      context,
      lebensmittelName: _formular.name,
      portion: p,
      fluessig: _formular.fluessig,
    );
    if (ergebnis == null || !mounted) return;
    final id = _formular.lebensmittelId;
    final gespeichert = id != null && p.id != null;
    switch (ergebnis) {
      case PortionGesichert(:final name, :final mengeG):
        final neu = p.mit(name: name, mengeG: mengeG);
        if (!gespeichert) {
          _setze(_formular.mitGeaenderterPortion(p, neu));
          return;
        }
        final liste = await _schreibe((e) => e.aenderePortion(id, neu));
        if (liste != null) _setze(_formular.mitPortionen(liste));
      case PortionGeloescht():
        if (!gespeichert) {
          _setze(_formular.ohnePortion(p));
          return;
        }
        final liste = await _schreibe((e) => e.loeschePortion(id, p));
        if (liste != null) _setze(_formular.mitPortionen(liste));
    }
  }

  /// Schreibt eine Portion über den Notifier und gibt die neue Liste aus
  /// der Tabelle — oder `null`, wenn es scheiterte oder das Blatt schon
  /// zu ist. Ein Fehler lässt das Blatt stehen, wie es war.
  Future<List<Portion>?> _schreibe(
    Future<List<Portion>> Function(ErfassenNotifier erfassen) arbeit,
  ) async {
    setState(() => _laeuft = true);
    try {
      final liste = await arbeit(ref.read(erfassenProvider.notifier));
      return mounted ? liste : null;
    } catch (fehler) {
      debugPrint('Portion nicht geschrieben: $fehler');
      return null;
    } finally {
      if (mounted) setState(() => _laeuft = false);
    }
  }

  Future<void> _sichere() async {
    setState(() => _laeuft = true);
    final erfassen = ref.read(erfassenProvider.notifier);
    int? neu;
    try {
      if (_aendert) {
        await erfassen.aendere(_formular);
      } else {
        neu = await erfassen.buche(_formular);
      }
    } catch (_) {
      // Ein gescheitertes Buchen meldet kein „fertig" — sonst schlösse
      // der Aufrufer das Blatt, und die Eingabe wäre weg.
      if (mounted) setState(() => _laeuft = false);
      return;
    }
    if (!mounted) return;
    // Gebucht ist gebucht. Fehlte dabei die Freigabe für Health, sagt das
    // **ein** Hinweis, über dem Blatt — `erfassen.js`, `keine-freigabe`.
    if (ref.read(healthSchreibHinweisProvider)) {
      await zeigeHealthSchreibHinweis(context);
      ref.read(healthSchreibHinweisProvider.notifier).gesehen();
      if (!mounted) return;
    }
    setState(() => _laeuft = false);
    if (neu != null) widget.onGebucht?.call(neu);
    widget.onFertig?.call();
  }

  Future<void> _loesche() async {
    setState(() => _laeuft = true);
    try {
      await ref.read(erfassenProvider.notifier).loesche(_formular.alsEintrag());
    } catch (_) {
      if (mounted) setState(() => _laeuft = false);
      return;
    }
    if (!mounted) return;
    setState(() => _laeuft = false);
    widget.onFertig?.call();
  }

  Future<void> _waehleMahlzeit(BuildContext context) async {
    final gewaehlt = await waehleMahlzeit(context);
    if (gewaehlt == null || !mounted) return;
    // **Umhängen zieht die Uhrzeit mit** — sonst trüge ein umgehängtes
    // Frühstück die Uhrzeit 19:00.
    setState(() => _formular = _formular.mitMahlzeit(gewaehlt));
  }

  Future<void> _waehleUhrzeit(BuildContext context) async {
    final minuten = await waehleUhrzeit(
      context,
      _formular.minutenSeitMitternacht,
    );
    if (!mounted) return;
    // **Die Mahlzeit bleibt stehen**, auch über die Fenstergrenze: Sie
    // steht am Eintrag, nicht an seiner Uhrzeit.
    setState(() => _formular = _formular.mitUhrzeit(minuten));
  }
}

/// Die gerechneten Nährwerte dieser Portion.
///
/// **Der Block steht immer da, auch ungefüllt** (`CLAUDE.md`, „Eine
/// Anzeige, die es gibt, hat genau eine Form"): Dieselbe Höhe, dieselbe
/// Breite, dieselbe Stelle — nur die Füllung unterscheidet sich. Fiele er
/// ohne lesbare Menge weg, spränge das Blatt bei jedem Tastendruck.
///
/// Ein fehlender Wert steht als `–/–` da, **nicht als 0**: Eine Null
/// behauptete „enthält keins davon" (Fehler `01`).
class _Naehrwertblock extends StatelessWidget {
  const _Naehrwertblock({super.key, required this.werte});

  final Naehrwerte werte;

  @override
  Widget build(BuildContext context) {
    return InsetCard(
      child: Column(
        children: [
          _zeile('Kalorien', werte.kcal, 'kcal'),
          const ErfassenTrenner(),
          _zeile('Eiweiß', werte.eiweissG, 'g', stellen: 1),
          const ErfassenTrenner(),
          _zeile('Kohlenhydrate', werte.kohlenhydrateG, 'g', stellen: 1),
          const ErfassenTrenner(),
          _zeile('davon Zucker', werte.zuckerG, 'g', stellen: 1),
          const ErfassenTrenner(),
          _zeile('Fett', werte.fettG, 'g', stellen: 1),
          const ErfassenTrenner(),
          _zeile('davon gesättigt', werte.gesaettigtG, 'g', stellen: 1),
          const ErfassenTrenner(),
          _zeile('Ballaststoffe', werte.ballaststoffeG, 'g', stellen: 1),
        ],
      ),
    );
  }

  Widget _zeile(String titel, double? wert, String einheit, {int stellen = 0}) {
    return ErfassenWertZeile(
      titel: titel,
      wert: wert == null
          ? ohneWert
          : '${formatNumber(wert, nachkommastellen: stellen)} $einheit',
    );
  }
}

/// Der Hinweis, dass Ernährung gerade nicht nach Apple Health darf (#283) —
/// gezeichnet in `docs/screens/screens/erfassen.js`, Zustand
/// `keine-freigabe`.
///
/// **Einmal je App-Lauf**, nicht je Eintrag; das hält
/// `healthSchreibHinweisProvider`. Der Satz nennt den Weg, statt einen
/// Knopf anzubieten: Ein Sprung in die Einstellungen landete bei der App,
/// nicht in der Health-App.
Future<void> zeigeHealthSchreibHinweis(BuildContext context) =>
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogKontext) => CupertinoAlertDialog(
        key: const Key('health-schreib-hinweis'),
        title: const Text('Nicht in Apple Health'),
        content: const Text(
          'Gebucht ist der Eintrag — in der App. Nach Apple Health darf sie '
          'deine Ernährung gerade nicht schreiben. Erlauben lässt sich das in '
          'der Health-App unter „Profil › Apps"; danach trägt die App alles '
          'Offene beim nächsten Buchen nach.',
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(dialogKontext).pop(),
            child: const Text('Verstanden'),
          ),
        ],
      ),
    );
