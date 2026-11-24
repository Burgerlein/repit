// Der Schirm „Umfänge messen" (#477 unter #88, Scheibe 2) — fünfzehn Maße
// mit dem Maßband, gruppiert nach Körperregion.
//
// API und Verhalten sind durch `app/test/shell/umfaenge_eintragen_test.dart`
// verbindlich vorgegeben (siehe dessen Dateikopf) — diese Datei darf die
// Tests ausführen, aber nicht verändern (`CLAUDE.md`, „Wer Tests schreibt,
// schreibt nicht die Implementierung").
//
// Aufbau nach `docs/screens/screens/umfaenge-eintragen.js`, Varianten `neu`,
// `schon-da` und `erstes-mal`.
//
// **Ein geschobener Schirm, kein Blatt.** Der Entwurf legte ein `sheet`
// über die Liste; der Swift-Code begründet das Gegenteil
// (`CircumferenceEntryView.swift:4-9`: „Dreizehn Felder zwischen zwei
// Diagrammen scrollen sich schlecht, und die Tastatur verdeckt dann genau
// das, was man vergleichen will"). Bei fünfzehn Feldern gilt das erst recht;
// der Entwurf ist am 11.11.2026 nachgezogen.
//
// **Gruppiert nach Körperregion, nicht nach Wichtigkeit:** Beim Messen
// arbeitet man mit dem Maßband den Körper hinunter. Die Übersicht sortiert
// umgekehrt — zwei Fragen, zwei Reihenfolgen.
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../data/umfaenge_repository.dart';
import '../design/formatierung.dart';
import '../design/glas_abstand.dart';
import '../design/inset_card.dart';
import '../design/palette.dart';
import '../design/platzhalter.dart';
import '../design/zahlen.dart';
import '../health/health_provider.dart';
import '../shell/mess_abschnitte.dart' show datumZumAnzeigen;
import '../shell/router.dart';
import '../shell/ziele.dart';
import 'umfaenge_provider.dart';

/// Öffnet das Formular auf dem Stapel des **aktuell gewählten** Tabs — die
/// eine Stelle, die das weiß. Von hier rufen `MehrView` und die Übersicht.
///
/// [tag] ist der ISO-Tagesstring, für den eingetragen werden soll; ohne ihn
/// der heutige Tag.
void oeffneUmfaengeEintragen(AppRouter router, {String? tag}) => router.open(
  AppTarget.aktuell((context) => UmfaengeEintragenSeite(tag: tag)),
);

/// Der Satz, der sagt, dass Sichern **ändert** statt anzulegen. Wörtlich aus
/// Spec und Entwurf — die einzige Stelle, an der der Schirm das sagt.
const String umfaengeSchonGemessenHinweis =
    'Für diesen Tag ist schon eine Messung eingetragen. Sichern ändert '
    'sie, statt eine zweite anzulegen.';

/// **Kein eigener `Navigator`:** Diese Ansicht wird auf den Stapel eines
/// Tabs geschoben, der Stapel gehört weiter `RootView`.
class UmfaengeEintragenSeite extends ConsumerStatefulWidget {
  const UmfaengeEintragenSeite({super.key, this.tag});

  /// Der Tag, der beim Öffnen gewählt ist. `null` heißt heute.
  final String? tag;

  @override
  ConsumerState<UmfaengeEintragenSeite> createState() =>
      _UmfaengeEintragenZustand();
}

class _UmfaengeEintragenZustand extends ConsumerState<UmfaengeEintragenSeite> {
  /// Heute **aus der Uhr der App**, nie `DateTime.now()` — sonst wäre der
  /// Schirm nicht deterministisch prüfbar.
  late final String _heute = BerlinCalendar.dayKey(ref.read(clockProvider)());

  late String _tag = widget.tag ?? _heute;

  final Map<Umfang, TextEditingController> _felder = {
    for (final mass in Umfang.values) mass: TextEditingController(),
  };

  /// Ob das Datumsrad aufgeklappt ist. Zugeklappt beim Öffnen: Fünfzehn
  /// Felder sind das, weswegen man herkommt.
  bool _radOffen = false;

  /// Was beim letzten Tipp auf „Sichern" nicht getragen hat, oder `null`.
  ///
  /// **Geprüft wird erst beim Sichern**, nicht beim Tippen: „27," ist ein
  /// gültiger Zwischenstand, und ein Feld, das beim dritten Anschlag rot
  /// wird, erzieht zum Wegschauen.
  String? _problem;

  /// Für welchen Tag die Felder schon mit den Werten dieses Tages belegt
  /// wurden. Ohne diesen Merker überschriebe jeder Rebuild, was gerade
  /// getippt wird.
  String? _belegtFuer;

  @override
  void dispose() {
    for (final feld in _felder.values) {
      feld.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stand = ref.watch(umfangsFormularProvider(_tag));
    // **Zustand und Nutzlast getrennt** (wie `messLageAus` in
    // `mess_abschnitte.dart`). Ein `is … ? … : null` ebnete beide in einem
    // Schritt ein: Von drei Fällen des sealed-Typs blieben zwei Auskünfte,
    // und ein gescheitertes Lesen sähe aus wie ein laufendes.
    final lage = formularLageAus(stand);
    final gelesen = formularWerte(stand);

    // Die Werte des gewählten Tages wandern **nach** dem Bild in die
    // Felder: `TextEditingController.text` im Bauen zu setzen löste einen
    // zweiten Aufbau aus, während der erste noch läuft.
    if (gelesen != null && _belegtFuer != _tag) {
      _belegeNachDemBild(_tag, gelesen);
    }

    return CupertinoPageScaffold(
      key: const Key('umfaenge-eintragen'),
      backgroundColor: CupertinoDynamicColor.resolve(Palette.bg, context),
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Umfänge messen'),
        trailing: CupertinoButton(
          key: const Key('umfaenge-eintragen-sichern'),
          padding: EdgeInsets.zero,
          minimumSize: const Size(44, 36),
          onPressed: _sichere,
          child: const Text('Sichern'),
        ),
      ),
      child: SingleChildScrollView(
        // Unten durchzeichnen statt abschneiden (`CLAUDE.md`,
        // flutter#179482): Die halbtransparente Tastatur schiebt sich über
        // den Schirm, und wo Flutter nicht zeichnet, steht Schwarz.
        padding:
            GlasAbstand.of(context) +
            EdgeInsets.only(
              bottom: 32 + MediaQuery.of(context).viewInsets.bottom,
            ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _inhalt(context, lage, gelesen),
        ),
      ),
    );
  }

  List<Widget> _inhalt(
    BuildContext context,
    FormularLage lage,
    FormularGelesen? gelesen,
  ) {
    final warn = CupertinoDynamicColor.resolve(Palette.warn, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final problem = _problem;

    return [
      if (problem != null)
        _Notiz(
          key: const Key('umfaenge-eintragen-problem'),
          ton: warn,
          text: problem,
        ),
      // Der dritte Fall des sealed-Typs, und er sagt etwas anderes als
      // „lädt": Nach einem gescheiterten Lesen läuft nichts mehr, und
      // warum die Vorwerte fehlen, erführe sonst niemand.
      if (lage == FormularLage.unlesbar)
        _Notiz(
          key: const Key('umfaenge-eintragen-unlesbar'),
          ton: warn,
          text:
              'Die Werte vom letzten Mal ließen sich nicht lesen. Messen '
              'und sichern geht trotzdem.',
        ),
      // Solange niemand weiß, ob für diesen Tag etwas vorliegt, wird es
      // auch nicht behauptet — der Ladezustand ist kein Leerstand (`01`).
      if (gelesen != null && gelesen.schonGemessen)
        _Notiz(
          key: const Key('umfaenge-eintragen-hinweis'),
          ton: muted,
          text: umfaengeSchonGemessenHinweis,
        ),
      const _Kapitel('Datum'),
      InsetCard(child: _datum(context)),
      for (final gruppe in UmfangsGruppe.values) ...[
        _Kapitel(_gruppenTitel(gruppe)),
        InsetCard(child: _gruppenKarte(context, gruppe, gelesen)),
        // Der Fuß steht **einmal**, unter der ersten Karte, und in jedem
        // Zustand an derselben Stelle: Stünde er mal da und mal nicht,
        // verschöbe sich alles darunter, sobald die erste Messung da ist.
        if (gruppe == UmfangsGruppe.arme)
          _Fuss(
            key: const Key('umfaenge-eintragen-fuss'),
            text: _fusstext(lage, gelesen),
          ),
      ],
    ];
  }

  // ───────────────────────────────────────────────────────────────────────
  // Das Datum
  // ───────────────────────────────────────────────────────────────────────

  Widget _datum(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final line = CupertinoDynamicColor.resolve(Palette.line, context);
    final datum = Format.tag(datumZumAnzeigen(_tag));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          key: const Key('umfaenge-eintragen-datum'),
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _radOffen = !_radOffen),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Expanded(
                  child: Text('Gemessen am', style: TextStyle(color: ink)),
                ),
                Text(
                  _tag == _heute ? 'Heute, $datum' : datum,
                  style: TextStyle(fontSize: 15, color: muted),
                ),
              ],
            ),
          ),
        ),
        if (_radOffen) ...[
          Container(height: 1, color: line),
          SizedBox(
            height: 180,
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.date,
              initialDateTime: _alsLokalesDatum(_tag),
              // Ohne Obergrenze ließe sich ein Umfang für übermorgen
              // eintragen, und der stünde im Verlauf vor seiner Messung.
              maximumDate: _alsLokalesDatum(_heute),
              // **Der Tagesstring kommt aus den Kalenderfeldern des
              // Rades.** Wer den Zeitpunkt stattdessen nach UTC dreht,
              // verschiebt den Tag um einen (`CLAUDE.md`).
              onDateTimeChanged: (wert) => _waehleTag(_alsTagesstring(wert)),
            ),
          ),
        ],
      ],
    );
  }

  static DateTime _alsLokalesDatum(String tag) {
    final teile = tag.split('-').map(int.parse).toList();
    return DateTime(teile[0], teile[1], teile[2]);
  }

  static String _alsTagesstring(DateTime datum) =>
      '${datum.year.toString().padLeft(4, '0')}-'
      '${datum.month.toString().padLeft(2, '0')}-'
      '${datum.day.toString().padLeft(2, '0')}';

  /// Ein anderer Tag heißt: andere Werte, andere Vorwerte, nichts von dem,
  /// was dasteht, gehört noch hierher. Bliebe eine Zahl stehen, würde sie
  /// beim Sichern zu einer Messung dieses Tages.
  void _waehleTag(String tag) {
    if (tag == _tag) return;
    setState(() {
      _tag = tag;
      _belegtFuer = null;
      _problem = null;
      for (final feld in _felder.values) {
        feld.clear();
      }
    });
  }

  // ───────────────────────────────────────────────────────────────────────
  // Die fünfzehn Felder
  // ───────────────────────────────────────────────────────────────────────

  String _gruppenTitel(UmfangsGruppe gruppe) => switch (gruppe) {
    UmfangsGruppe.arme => 'Arme',
    UmfangsGruppe.rumpf => 'Rumpf',
    UmfangsGruppe.beine => 'Beine',
  };

  Widget _gruppenKarte(
    BuildContext context,
    UmfangsGruppe gruppe,
    FormularGelesen? gelesen,
  ) {
    final line = CupertinoDynamicColor.resolve(Palette.line, context);
    final masse = [
      for (final mass in Umfang.values)
        if (mass.gruppe == gruppe) mass,
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < masse.length; i++) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.only(left: 14),
              child: Container(height: 1, color: line),
            ),
          _feldZeile(context, masse[i], gelesen),
        ],
      ],
    );
  }

  /// Eine Zeile: Name links, Feld rechts, Einheit dahinter.
  ///
  /// **Die Zeile steht in jedem Zustand da**, mit und ohne Vorwert — ein
  /// Feld, das ohne Vorwert wegfiele, sähe aus wie ein Maß, das die App
  /// nicht kennt.
  Widget _feldZeile(
    BuildContext context,
    Umfang mass,
    FormularGelesen? gelesen,
  ) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final vorwert = gelesen?.vorwerte[mass];

    return Padding(
      key: Key('umfaenge-zeile-${mass.schluessel}'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              mass.deutsch,
              style: TextStyle(fontSize: 15, color: ink),
            ),
          ),
          SizedBox(
            width: 92,
            height: 36,
            child: CupertinoTextField(
              key: Key('umfaenge-feld-${mass.schluessel}'),
              controller: _felder[mass],
              // Der Vorwert ist ein Vergleich, keine Eingabe — gespeichert
              // wird, was getippt wird.
              placeholder: vorwert == null
                  ? null
                  : formatNumber(vorwert, nachkommastellen: 1),
              decoration: null,
              textAlign: TextAlign.right,
              padding: const EdgeInsets.symmetric(vertical: 8),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: TextStyle(fontSize: 16, color: ink),
            ),
          ),
          const SizedBox(width: 6),
          Text('cm', style: TextStyle(fontSize: 13, color: muted)),
        ],
      ),
    );
  }

  /// Der Satz unter der ersten Karte. **Er nennt erst dann einen Grund,
  /// wenn einer bekannt ist**: „Vorher wurde nichts gemessen" wäre während
  /// des Lesens und nach einem gescheiterten Lauf geraten — Fehler `01`.
  String _fusstext(FormularLage lage, FormularGelesen? gelesen) {
    const grenzen = '10 bis 200 cm, mit Komma oder Punkt.';
    return switch (lage) {
      FormularLage.laedt || FormularLage.unlesbar =>
        '$grenzen Leere Felder werden nicht gespeichert.',
      FormularLage.gelesen when gelesen!.vorwerte.isEmpty =>
        'Vorher wurde nichts gemessen, es gibt also keine Vorwerte. '
            '$grenzen Du musst nicht alles messen; leere Felder bleiben '
            'leer.',
      FormularLage.gelesen =>
        'Platzhalter sind die Werte vom letzten Mal. $grenzen '
            'Leere Felder werden nicht gespeichert.',
    };
  }

  // ───────────────────────────────────────────────────────────────────────
  // Belegen und Sichern
  // ───────────────────────────────────────────────────────────────────────

  /// Für einen Tag, an dem schon gemessen wurde, stehen dessen Werte
  /// **wirklich** in den Feldern — als Text, änderbar, nicht blass (Tim,
  /// 11.11.2026): Man soll sehen, welche Zahl bestätigt ist und welche nur
  /// vorgeschlagen.
  ///
  /// Belegt wird nur, was leer ist: Wer tippt, während noch gelesen wird,
  /// behält seine Zahl.
  void _belegeNachDemBild(String tag, FormularGelesen gelesen) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _tag != tag || _belegtFuer == tag) return;
      setState(() {
        _belegtFuer = tag;
        for (final mass in Umfang.values) {
          final wert = gelesen.werteAmTag[mass];
          if (wert == null) continue;
          final feld = _felder[mass]!;
          if (feld.text.isEmpty) {
            feld.text = formatNumber(wert, nachkommastellen: 1);
          }
        }
      });
    });
  }

  /// Ein halb getippter Wert ist beim Sichern keine Zahl mehr.
  ///
  /// `UmfangsEingabe.parse` liest „27," über `double.tryParse('27.')` als
  /// 27,0 — ein Rest, den niemand so gemeint hat, und 27 cm liegen innerhalb
  /// der Grenzen, fielen also nicht auf. Der Schirm weist ihn deshalb ab,
  /// statt eine Zahl abzulegen, die nie gemessen wurde. **Im Bericht
  /// gemeldet:** Die Grenze gehörte in den Kern, und dort ist sie nicht.
  UmfangsEingabeErgebnis _gelesen(String text) {
    final gekuerzt = text.trim();
    if (gekuerzt.endsWith(',') || gekuerzt.endsWith('.')) {
      return const UmfangKeineZahl();
    }
    return UmfangsEingabe.parse(text);
  }

  Future<void> _sichere() async {
    final werte = <Umfang, double>{};
    final probleme = <String>[];

    for (final mass in Umfang.values) {
      final text = _felder[mass]!.text;
      switch (_gelesen(text)) {
        case UmfangOk(:final zentimeter):
          werte[mass] = zentimeter;
        case UmfangLeer():
          break;
        case UmfangKeineZahl():
          probleme.add('${mass.deutsch}: „${text.trim()}" ist keine Zahl.');
        case UmfangAusserhalb(:final gelesen):
          probleme.add(
            '${mass.deutsch}: '
            '${formatNumber(gelesen, nachkommastellen: 1)} cm liegt '
            'außerhalb von '
            '${formatNumber(UmfangsEingabe.minCm, nachkommastellen: 0)} bis '
            '${formatNumber(UmfangsEingabe.maxCm, nachkommastellen: 0)} cm.',
          );
      }
    }

    // Abgewiesen heißt abgewiesen: Auch die gültigen Felder werden nicht
    // halb gespeichert, sonst stünde eine Messung da, die niemand bestätigt
    // hat. Und der Schirm bleibt stehen — zugegangen nähme er die
    // eingetippten Zahlen mit.
    if (probleme.isNotEmpty) {
      setState(() => _problem = probleme.join(' '));
      return;
    }
    if (werte.isEmpty) {
      setState(
        () => _problem = 'Trag mindestens ein Maß ein, bevor du sicherst.',
      );
      return;
    }

    final tag = _tag;
    await ref
        .read(umfaengeRepositoryProvider)
        .schreibeGetippt(tag: tag, werte: werte);
    if (!mounted) return;

    // Die Übersicht, die Kachel auf `koerper` und die Vorwerte zeigen
    // jetzt etwas anderes — ohne das stünde der eben eingetragene Tag
    // nicht in der Liste und sein Wert beim nächsten Öffnen nicht als
    // Vorwert da (`32`).
    umfaengeNeuGelesen(ref);
    Navigator.of(context).pop();
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Bausteine
// ─────────────────────────────────────────────────────────────────────────

/// Die Überschrift über einer Karte — `formHead` im Entwurf.
class _Kapitel extends StatelessWidget {
  const _Kapitel(this.titel);

  final String titel;

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);

    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 7, left: 4),
      child: Text(
        titel.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: muted,
        ),
      ),
    );
  }
}

/// Der erklärende Satz unter der ersten Karte — `formFoot` im Entwurf.
///
/// **Feste Zeilenzahl**, weil derselbe Fuß drei verschiedene Sätze trägt:
/// Ohne Reservierung rutschten Rumpf und Beine, sobald die erste Messung da
/// ist (`CLAUDE.md`, „Mehrzeilige Erläuterungen bekommen eine feste
/// Zeilenzahl").
class _Fuss extends StatelessWidget {
  const _Fuss({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final stil = TextStyle(fontSize: 12, height: 1.33, color: muted);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 7, 4, 0),
      child: FesteZeilen(
        zeilen: 3,
        stil: stil,
        child: Text(
          text,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: stil,
        ),
      ),
    );
  }
}

/// Der Kasten mit farbiger Kante — `noteBox` im Entwurf, dieselbe Form wie
/// in `gewicht_eintragen.dart`.
class _Notiz extends StatelessWidget {
  const _Notiz({super.key, required this.ton, required this.text});

  final Color ton;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: ton.withValues(alpha: 0.12),
        border: Border(left: BorderSide(color: ton, width: 3)),
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 13, height: 1.35, color: ink),
      ),
    );
  }
}
